#asciidoctor-pdf -r asciidoctor-mathematical -a pdf-theme=resources/theme.yml -a env-pdf asciidoc/README.adoc -o README.pdf
asciidoctor-pdf -a env-pdf asciidoc/README.adoc -o README.pdf
rm -rf stem*
#asciidoctor -a env-web asciidoc/README.adoc -o README.html
