.PHONY: clean

clean:
	find src -type f \( -name '*.so' -o -name '*.wpo' \) -delete
