.PHONY: clean tarball tarball-check

clean:
	find src -type f \( -name '*.so' -o -name '*.wpo' \) -delete

tarball:
	sh release.sh

tarball-check:
	bash checks/release-acceptance.sh
