#
# Copyright 2021, Seqera Labs, S.L. All Rights Reserved.
#

## DNAnexus quickstart
clean:
	rm -rf build

dx-pack:
	mkdir -p build/nextflow-hello/resources/usr/bin
	mkdir -p build/nextflow-hello/resources/opt/nextflow
	NXF_VER=21.04.0 NXF_HOME=build/nextflow-hello/resources/opt/nextflow bash -c 'curl -s get.nextflow.io | bash'
	mv nextflow build/nextflow-hello/resources/usr/bin/nextflow
	rm -rf build/nextflow-hello/resources/opt/nextflow/tmp

dx-build:
  # copy dnanexus template
	cp -r app/* build/nextflow-hello/
	dx build build/nextflow-hello -f
	# info
	echo "Run with: dx run nextflow-hello --watch -y"

dx-run:
	dx run nextflow-hello --watch -y
