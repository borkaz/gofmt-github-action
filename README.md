# gofmt Docker container action

This Github Docker container action executes gofmt command and returns the command output on failure.

This is a fork of the [sladyn98/auto-go-format](https://github.com/sladyn98/auto-go-format) repository
with minor code changes and deprecation warnings removed.

## Example Usage

```yaml
uses: borkaz/go-fmt-action@v1.0.0
with:
  gofmt-path: './src'
  gofmt-flags: '-l -d'
````
