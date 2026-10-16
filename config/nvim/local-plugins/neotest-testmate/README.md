# neotest-testmate

## Why

If you're like me, then you have a team that integrated their C++ unit tests
with the increadible VSCode plugin
[TestMate C++](https://github.com/matepek/vscode-catch2-test-adapter). However,
this is not good enough for our nvim powered heart. And unfortunatelly for us,
[neotest-ctest](https://github.com/orjangj/neotest-ctest) doesn't seem to work
for the current setup. Not the plugins fault of course, it turns out that
putting all the tests in a single test binary just doesn't play well with CTest.
