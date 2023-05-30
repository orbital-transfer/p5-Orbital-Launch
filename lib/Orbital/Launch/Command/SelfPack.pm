package Orbital::Launch::Command::SelfPack;
# ABSTRACT: Pack self and dependencies

use Orbital::Transfer::Common::Setup;
use Moo;
use CLI::Osprey on_demand => 1;
use Path::Tiny;
use File::chdir;
use CPAN::Meta;
use Module::Metadata;
use List::Util::MaybeXS qw(uniq);
use B qw(perlstring);
use Data::Graph::Util qw(toposort is_acyclic);
use CPAN::Mirror::Tiny;
use Capture::Tiny qw(capture_stdout);
use JSON::MaybeXS;
use Archive::Extract;
use Distribution::Metadata;
use local::lib ();
use version 0.77;
use App::FatPacker::Simple;

sub get_dzil_info {
	my ($dir) = @_;
	my ($info, $exit) = capture_stdout {
		system($^X, qw(-e), <<'CODE', $dir );
			use Test::DZil;
			use File::Temp qw(tempdir);
			use JSON::MaybeXS;

			my $dist_root = shift @ARGV;
			my $temp_dir = tempdir( CLEANUP => 1 );

			my $dz = Test::DZil::Builder()->from_config(
				{ dist_root => $dist_root },
				{ tempdir_root => $temp_dir },
			);

			print encode_json({ name => $dz->name, version => $dz->version });
CODE
	};
	die "Could not get info" unless 0 == $exit;

	return decode_json( $info );
}

method run() {
	die "Need paths" unless @ARGV == 2;

	my $input_path  = path(shift @ARGV);
	my $output_path = path(shift @ARGV);

	die "Input path does not exist" unless -d $input_path;

	my @children = grep { -d } $input_path->children;
	my @meta;
	for my $child (@children) {
		unless( $child->child('dist.ini') ) {
			warn "$child is not a dzil repo!";
			next;
		}

		my $dzil_info = get_dzil_info($child);
		my $target_tarball = $output_path->child(
			join('-', @$dzil_info{qw(name version)})
			. '.tar.gz'
		);

		my ($meta, $packages, $final_build_tgz);

		unless( -f $target_tarball ) {
			my $build_output = $output_path->child('build-dir')->absolute;
			die "Output dir already exists" if -d $build_output;
			$build_output->mkpath;

			{
				local $CWD = $child;
				system( qw(dzil build),
					qw(--in), $build_output
				) == 0 or die "Could not build $child";
			}

			$meta = CPAN::Meta->load_file( $build_output->child('META.json') );
			$packages = Module::Metadata->package_versions_from_directory($build_output);

			my $new_name = join "-", $meta->name, $meta->version;
			my $final_build_output = $output_path->child($new_name);
			die "Final build dir already exists" if -d $final_build_output;
			$build_output->move($final_build_output);
			$final_build_tgz = $output_path->child("${new_name}.tar.gz");

			{
				local $CWD = $output_path;
				system( qw(tar czf), $final_build_tgz->basename, $new_name, );
			}

			$final_build_output->remove_tree;
		} else {
			$final_build_tgz = $target_tarball;

			my $ae = Archive::Extract->new( archive => $final_build_tgz );
			my $top = Path::Tiny->tempdir;
			$ae->extract( to => $top );

			my ($build_output) = $top->children;

			$meta = CPAN::Meta->load_file( $build_output->child('META.json') );
			$packages = Module::Metadata->package_versions_from_directory($build_output);
		}

		push @meta, {
			name => $meta->name,
			version => $meta->version,
			path => $final_build_tgz->absolute,
			meta => $meta,
			packages => $packages,
		};
	}

	my %package_to_name = map {
		my $name = $_->{name};
		map { $_ => $name } keys %{ $_->{packages} }
	} @meta;

	my %dep_data = map {
		my $rr = $_->{meta}->prereqs->{runtime}{requires};
		my @have = uniq map { exists $package_to_name{$_} ? $package_to_name{$_} : () } keys %$rr;
		$_->{name} => \@have
	} @meta;

	die "Depedencies are cyclic!" unless is_acyclic(\%dep_data);

	my %meta_by_name = map { $_->{name} => $_ } @meta;

	my @sorted = reverse toposort(\%dep_data);

	my $cpanfile = path($output_path)->child('cpanfile');
	my $cpanfile_content = join "", map {
		<<EOF
requires @{[ perlstring($_->{name} =~ s/-/::/gr ) ]};# , url => @{[ perlstring('file://' . $_->{path}->stringify)  ]};
EOF
	} @meta_by_name{@sorted};
	$cpanfile->spew_utf8( "$cpanfile_content" );

	my $local_lib_path = $output_path->child('local')->absolute;
	local $ENV{PERL_CARTON_PATH} = $local_lib_path;

	{
		local $CWD = $output_path;
		system(
			qw(cpan-mirror-tiny inject),
				map { $_->{path}->basename } @meta
		) if @meta;
		system( qw(cpan-mirror-tiny gen-index) );
		local $ENV{PERL_CARTON_MIRROR} = path('./darkpan')->absolute;

		system( qw( carton --verbose install ) );


		use ExtUtils::Installed;
		my $my_inc = [ local::lib->lib_paths_for($local_lib_path) ];
		my $installed = ExtUtils::Installed->new( inc_override => $my_inc );
		my @packages;
		for my $module (grep(!/^Perl$/, $installed->modules())) {
			my $dist_meta = Distribution::Metadata->new_from_module(
				$module,
				inc => $my_inc );
			my $mymeta = $dist_meta->mymeta_json_hash;
			my $version = exists $mymeta->{prereqs}{runtime}{requires}{perl}
				? $mymeta->{prereqs}{runtime}{requires}{perl}
				: 'v5';
			push @packages, [ $module, version->parse($version) ];
		}
		print join "\n",
			map { join "\t", $_->[0], $_->[1]->normal }
			sort {
				$a->[1] <=> $b->[1]
				or $a->[0] cmp $b->[0]
			} @packages;
		print "\n";

	}

	{
		local $CWD = $output_path;
		my $pack_name = path('orbitalism.packed');
		$pack_name->remove if -f $pack_name;
		system(
			$^X,
			qq(-Mlocal::lib=${local_lib_path}),
			qw(-S fatpack-simple),
			qw(-d), $local_lib_path,
			qw(-e), join(',', qw(Module::Build ExtUtils::MakeMaker) ),
			qw(-o), $pack_name,
			$local_lib_path->child(qw(bin orbitalism)),
		) == 0 or die "Could not pack";
	}
}

1;
