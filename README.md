# Underscore-Folly

A collection of utilities inspired by underscore.js utilizing the folly bundler.


## Documentation

Documentation is interspersed in the code itself, which is broken into individual files in the lib directory by utility type. Browser.coffee is sourced when the folly bundler builds for the browser. Index.coffee is sourced on the server, and is a superset of browser.coffee.

## Tests

For the time being, the test directory is just a collection of ad hoc tests. A legitimate test suite would be preferable.

## High-level todos

After folly, hash-folly and debug-folly are released:

- [ ] re-add hash functions in files
- [ ] re-add debug

Eventually:

- [ ] add a proper test suite
- [ ] add continuous integration through Tavis
- [ ] add automatic documentation generation
- [ ] host docs on github
- [ ] move these todo lists into github's bug tracking system

