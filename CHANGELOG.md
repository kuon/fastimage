# Changelog

## v0.0.7

[bug fixes]
- Fix for [issue #9](https://github.com/stephenmoloney/fastimage/issues/9)

[changes]
- remove dependency on [Og](https://hex.pm/packages/og)


## v0.0.6

- Remove compile warnings.


## v0.0.5

- Allow up to 5 retry attempts to stream the url in the event of a timeout (enhancement/bug fix)


## v0.0.4

- Follow up to three redirects for image files
- Increase timeout for `test "Get the size of multiple image files asynchronously"` from `5000` -> `10000`


## v0.0.3

- Remove warning messages


## v0.0.2

- Change client from `:gun` to `:hackney`.
- Add more extensive tests.


## v0.0.1

- Initial release.