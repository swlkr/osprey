# Changelog
All notable changes to this project will be documented in this file.

## Unreleased - ???
- Sinatra like api
- [Upper case http method names](https://github.com/swlkr/osprey/pull/1) Thanks to @pepe
- Add `ok` function (helper for status 200)
- Add `text/html`, `application/json`, `text/plain` content-type functions
- Remove `add-header` function
- Make `app` public
- Add `render` function
- Add `enable` function
- Add `(enable :static-files)`
- Add `(enable :sessions)`
- Add `(enable :csrf-tokens)`
- Add `halt` function
- Add multipart/form-data parsing
- Change `html/encode` to handle strings without tags
- Use `janet-html` to share html rendering with joy
- Automatically parse form encoded bodies and put the results in `params`
- Added flash message support when `(enable :sessions)` is called
