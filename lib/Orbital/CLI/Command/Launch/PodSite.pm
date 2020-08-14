use Orbital::Transfer::Common::Setup;
package Orbital::CLI::Command::Launch::PodSite;
# ABSTRACT: Build Pod::Site from repos

use Modern::Perl;
use Mu;
use CLI::Osprey;

method _setup() {
	system(qw());
}

method _build_all_repos() {
	...
}

method _run_podsite() {
<<'EOF'
	cpanm Pod::Site
	podsite \
		--doc-root $DOC_HTML_DIR \
		--base-uri '/~zaki/doc' \
		--name 'Project Renard' \
		$DOC_BUILD_DIR/*/{lib,bin}

	#cpanm Pod::Simple::HTMLBatch
	#perl -MPod::Simple::HTMLBatch -e 'Pod::Simple::HTMLBatch::go' $DOC_BUILD_DIR/*/lib $DOC_HTML_DIR

	perl -pi -E '
		s,\Qhttp://search.cpan.org/perldoc?\E,https://metacpan.org/pod/,g;
		s,\Qhttps://metacpan.org/pod/Gtk3::\E([^"]+),"https://developer.gnome.org/gtk3/stable/Gtk". ($1 =~ s|::||gr).".html" ,ge;
	' $(find $DOC_HTML_DIR -type f -name "*.html")

	perl -pi -E 's,\Q</a>—\E,</a>&nbsp;— ,g' $DOC_HTML_DIR/toc.html
	perl -pi -E '
		# CSS: #doc h1
		s/\Qborder-bottom: 1px solid #808080;\E//g;
		# CSS: #doc h2
		s/\Qborder-bottom: 1px dashed #808080\E//g;
	' $DOC_HTML_DIR/podsite.css
EOF
}

method run() {
	$self->_setup;
}

1;
