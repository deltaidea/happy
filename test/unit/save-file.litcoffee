# `saveFile` module

	describe "saveFile", ->

		saveFile = require "../../source/save-file"

		JsZip = require "jszip"

## What?

**`saveFile`** provides useful abstractions for saving text and binary files.

## How?

#### API

```CoffeeScript
saveFile = require "./save-file"

# Download a file and get it as `ArrayBuffer`.
saveFile.download
	url: "http://vk.com/favicon.ico"
	callback: ( err, file ) ->

# Save a text file.
saveFile.saveText
	text: "Hello, world!"
	filename: "hw.txt"

# Download and save multiple files.
saver = saveFile.saveMultipleAsZip concurrency: 3

saver.afterEach ( filename, doneCount, totalCount ) ->

saver.add url: "/foo.jpg", filename: "foo.jpg"
saver.add text: "Hello, world!", filename: "hw.txt"

saver.zip ( zipBlob ) ->
	saveAs zipBlob, "result.zip"
```

#### Use modern JavaScript features: `Blob` and `saveAs`.

This module uses `Blob` with
[a polyfill](https://www.npmjs.com/package/blob-polyfill) and `saveAs` with
[a polyfill](https://www.npmjs.com/package/filesaver.js).

## `saveFile.download`

Usage:

```CoffeeScript
saveFile.download
	url: "http://vk.com/favicon.ico"
	callback: ( err, file ) ->
```

Downloads a file and returns it as an `ArrayBuffer` to the callback.

		describe "download", ->

			it "should return an Error when no url is provided", ( done ) ->
				saveFile.download
					callback: ( err, file ) ->
						expect( file ).to.not.be.ok
						err.should.be.an.instanceof Error
						done()

			it "should return an Error when no callback is provided", ->
				result = saveFile.download
					url: "whatever"
				result.should.be.an.instanceof Error

			it "should download the file using ajax.get", ( done ) ->
				ajax = require "../../source/ajax"

				fakeCallback = ( err, file ) ->
					expect( err ).to.not.be.ok
					file.should.equal "fake-buffer"
					ajax.get.restore()
					done()

				# This is how a real result from `ajax.get` looks.
				fakeResult =
					response:
						response: "fake-buffer"

				sinon.stub ajax, "get", ({ url, responseType, callback }) ->
					url.should.equal "fake-url"
					responseType.should.equal "arraybuffer"
					# `ajax.get` returns result text as the first argument.
					# Obviously, there's no text when downloading binary files.
					callback null, fakeResult

				saveFile.download
					url: "fake-url"
					callback: fakeCallback

			it "should return an Error when no buffer in response", ( done ) ->
				ajax = require "../../source/ajax"

				fakeCallback = ( err, file ) ->
					err.should.be.an.instanceof Error
					expect( file ).to.not.be.ok
					ajax.get.restore()
					done()

				# This is how a real result from `ajax.get` looks.
				fakeResult =
					error: "Oops, no buffer!"

				sinon.stub ajax, "get", ({ url, responseType, callback }) ->
					url.should.equal "fake-url"
					responseType.should.equal "arraybuffer"
					callback null, fakeResult

				saveFile.download
					url: "fake-url"
					callback: fakeCallback

## `saveFile.saveMultipleAsZip`

Usage:

```CoffeeScript
saver = saveFile.saveMultipleAsZip concurrency: 3

saver.afterEach ( filename, doneCount, totalCount ) ->

saver.add url: "/foo.jpg", filename: "foo.jpg"
saver.add text: "Hello, world!", filename: "hw.txt"

saver.zip ( zipBlob ) ->
	saveAs zipBlob, "result.zip"
```

		describe "saveMultipleAsZip", ->

			it "should set concurrency to 3 by default", ->
				saver = saveFile.saveMultipleAsZip()
				saver.concurrency.should.equal 3

			it "should set concurrency to the provided number", ->
				saver = saveFile.saveMultipleAsZip concurrency: 100
				saver.concurrency.should.equal 100

			it "should return an object with method 'add'", ->
				saver = saveFile.saveMultipleAsZip()
				saver.add.should.be.a "function"

			it "should download files using 'saveFile.download'", ( done ) ->
				sinon.stub JsZip.prototype, "file", ( filename, file ) ->
					filename.should.equal "fake-filename"
					file.should.equal "fake-file"

					JsZip.prototype.file.restore()
					saveFile.download.restore()
					done()

				sinon.stub saveFile, "download", ({ url, callback }) ->
					url.should.equal "fake-url"
					callback null, "fake-file"

				saver = saveFile.saveMultipleAsZip()
				saver.add
					url: "fake-url"
					filename: "fake-filename"

			it "should save text files to the zip", ( done ) ->
				sinon.spy saveFile, "download"

				sinon.stub JsZip.prototype, "file", ( filename, file ) ->
					filename.should.equal "fake-filename"
					file.should.equal "fake-text"

					JsZip.prototype.file.restore()
					saveFile.download.should.not.have.been.called
					saveFile.download.restore()
					done()

				saver = saveFile.saveMultipleAsZip()
				saver.add
					text: "fake-text"
					filename: "fake-filename"

			# See also: https://github.com/caolan/async/pull/727
			it "should pass error to 'error' when download fails", ( done ) ->
				sinon.stub JsZip.prototype, "file"
					.throws()

				sinon.stub saveFile, "download", ({ callback }) ->
					callback new Error "Oh, snap!"

				saver = saveFile.saveMultipleAsZip()

				saver.error = ( err ) ->
					err.should.be.an.instanceof Error
					JsZip.prototype.file.restore()
					saveFile.download.restore()
					done()

				saver.add
					url: "fake-url"
					filename: "fake-filename"

			it "should not kill the queue when download fails", ( done ) ->
				sinon.stub JsZip.prototype, "file"
					.throws()

				sinon.stub saveFile, "download", ({ callback }) ->
					callback new Error "Oh, snap!"

				saver = saveFile.saveMultipleAsZip()

				saver.drain = ->
					JsZip.prototype.file.restore()
					saveFile.download.restore()
					done()

				saver.add
					url: "fake-url"
					filename: "fake-filename"

			it "should pass a zip blob to the 'zip' callback", ( done ) ->
				filesToAdd = [
					url: "fake-url-1"
					filename: "fake-filename-1"
				,
					url: "fake-url-2"
					filename: "fake-filename-2"
				,
					text: "fake-text-3"
					filename: "fake-filename-3"
				]

				addedFiles = []

				sinon.stub JsZip.prototype, "file", ( filename ) ->
					addedFiles.push filename

				sinon.stub JsZip.prototype, "generate", ({ type }) ->
					type.should.equal "blob"
					"fake-blob"

				sinon.stub saveFile, "download", ({ callback }) ->
					callback null, "fake-file"

				saver = saveFile.saveMultipleAsZip()

				saver.zip ( zipBlob ) ->
					for file in filesToAdd
						addedFiles.should.contain file.filename
					zipBlob.should.equal "fake-blob"
					JsZip.prototype.file.restore()
					JsZip.prototype.generate.restore()
					saveFile.download.restore()
					done()

				for file in filesToAdd
					saver.add file

			it "should call 'afterEach' after each file", ( done ) ->
				filesToAdd = [
					url: "fake-url-1"
					filename: "fake-filename-1"
				,
					url: "fake-url-2"
					filename: "fake-filename-2"
				,
					text: "fake-text-3"
					filename: "fake-filename-3"
				]

				addedFiles = []

				sinon.stub JsZip.prototype, "file", ->

				sinon.stub JsZip.prototype, "generate", ({ type }) ->
					type.should.equal "blob"
					"fake-blob"

				sinon.stub saveFile, "download", ({ callback }) ->
					callback null, "fake-file"

				saver = saveFile.saveMultipleAsZip()

				saver.afterEach ( filename, doneCount, totalCount ) ->
					addedFiles.push filename
					doneCount.should.equal addedFiles.length
					totalCount.should.equal filesToAdd.length

				saver.zip ( zipBlob ) ->
					for file in filesToAdd
						addedFiles.should.contain file.filename
					zipBlob.should.equal "fake-blob"
					JsZip.prototype.file.restore()
					JsZip.prototype.generate.restore()
					saveFile.download.restore()
					done()

				for file in filesToAdd
					saver.add file

			it "should have 'doneCount' and 'totalCount' properties", ( done ) ->
				filesToAdd = [
					url: "fake-url-1"
					filename: "fake-filename-1"
				,
					url: "fake-url-2"
					filename: "fake-filename-2"
				,
					text: "fake-text-3"
					filename: "fake-filename-3"
				]

				addedFiles = []

				sinon.stub JsZip.prototype, "file", ->
				sinon.stub JsZip.prototype, "generate", ->

				sinon.stub saveFile, "download", ({ callback }) ->
					callback null, "fake-file"

				saver = saveFile.saveMultipleAsZip()
				saver.doneCount.should.equal 0
				saver.totalCount.should.equal 0

				saver.afterEach ( filename ) ->
					addedFiles.push filename
					saver.doneCount.should.equal addedFiles.length
					saver.totalCount.should.equal filesToAdd.length

				saver.zip ->
					for file in filesToAdd
						addedFiles.should.contain file.filename
					JsZip.prototype.file.restore()
					JsZip.prototype.generate.restore()
					saveFile.download.restore()
					done()

				for file in filesToAdd
					saver.add file

				saver.totalCount.should.equal filesToAdd.length

			it "should not add files with already used filenames", ( done ) ->
				filesToAdd = [
					url: "fake-url-foo"
					filename: "fake-filename-1"
				,
					url: "fake-url-bar"
					filename: "fake-filename-2"
				,
					text: "fake-text-foo"
					filename: "fake-filename-3"
				]

				conflictingFiles = [
					text: "fake-text-bar"
					filename: "fake-filename-3"
				,
					text: "fake-text-qux"
					filename: "fake-filename-3"
				,
					url: "fake-url-qux"
					filename: "fake-filename-2"
				]

				addedFiles = []

				sinon.stub JsZip.prototype, "file", ( filename, content ) ->
					for file in conflictingFiles
						if content in [ file.text, file.url ]
							done new Error "added conflicting file #{content}"

				sinon.stub JsZip.prototype, "generate", ->

				sinon.stub saveFile, "download", ({ callback, url }) ->
					callback null, url

				saver = saveFile.saveMultipleAsZip()

				saver.afterEach ( filename ) ->
					addedFiles.push filename

				saver.zip ( zipBlob ) ->
					for file in filesToAdd
						addedFiles.should.contain file.filename
					JsZip.prototype.file.restore()
					JsZip.prototype.generate.restore()
					saveFile.download.restore()
					done()

				for file in filesToAdd
					saver.add file
				for file in conflictingFiles
					saver.add file

				saver.totalCount.should.equal 3

## `saveFile.saveText`

Synchronously saves a text file using `Blob` and `saveAs`.

```CoffeeScript
saveFile.saveText
	text: "Hello, world!"
	filename: "hw.txt"
```

		describe "saveText", ->

			it.skip "should be a thin wrapper around Blob and saveAs", ->
				# From cjohansen/Sinon.JS#743:
				# Native objects are notoriously unreliable as spying/stubbing
				# targets.
				#
				# Should find or publish thin wrappers for Blob and saveAs.
