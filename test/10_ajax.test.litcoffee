# app.ajax

	describe "app.ajax", ->

## What?

**`app.ajax`** provides interface for **same-origin** and
**cross-origin ajax requests**.

## Why?

Some features rely on cross-origin requests.

E.g. to get audio file size we need to make a `HEAD` request to `cs*.vk.me/*`
where the file is stored.

## How?

#### Use extension sandboxed script with elevated permissions.

Injected scripts (which we are testing here) can't make cross-origin requests
so we pass request data to some sort of background script which has enough
permissions. See `source/meta/**/*.js` for the background scripts.

**Note**: here "background script" means any sandboxed extension script, that
may be content script, user script, or background script.

To keep it simple and DRY let's handle same-origin requests in
background scripts too since there is no difference for them.

#### Talk with that script via `message` event on `window`.

Injected and background scripts talk to each other via `message` events
triggered on `window` object.  
See:
https://developer.mozilla.org/en-US/docs/Web/API/Window.postMessage

`app.ajax` sends a message with request data, background script captures it,
fetches response and passes it back with another message.

## Messages specification

#### Request message
**`app.ajax.*`** triggers **`message`** event on **`window`** object like so:
**`window.postMessage settings, "*"`**.

The `settings` object is guaranteed to have the following properties:
- **`method`** - `"GET"`, `"HEAD"`, `"POST"` - http request method
- **`url`** - `string` - target URL
- **`data`** - `object` - data to send
- **`_requestId`** - `string` - unique request identifier

#### Response message
**Background script** captures request message, processes it and
triggers **`message`** event on **`window`** object like so:
**`window.postMessage settings, "*"`**.

The `settings` object is guaranteed to have the following properties:
- **`method`** - `"GET"`, `"HEAD"`, `"POST"` - http request method
- **`url`** - `string` - target URL
- **`data`** - `object` - sent data
- **`_responseId`** - `string` - unique response identifier
equal to `_requestId` specified in request message

## Mimic background script for testing purposes

**`mimicBackgroundListener`** is a little helper which mimics
background script.  
It listens for a message which `app.ajax` sends, checks that sent data is
correct and invokes callback if provided.

**Note**: this helper never sends a message back with response.  
It just checks that request is correct and calls provided function
(which then may send a response message if needed).

		mimicBackgroundListener = ( callback, expectedData = {}) ->
			listener = ( message ) ->
				# Remove this listener once message is captured.
				window.removeEventListener "message", listener

				requestData = message.data
				for key, value of expectedData
					requestData.should.have.property key
					requestData[ key ].should.deep.equal value
				callback requestData if callback

			window.addEventListener "message", listener, no

## app.ajax.request
**`app.ajax.request`** is the central ajax method like `jQuery.ajax`.

		describe "request", ->

#### It sends request data to background script:

			it "should pass request data via 'message' event", ( done ) ->
				# Set up a background listener.
				mimicBackgroundListener ( -> done() ),
					method: "POST"
					url: "http://example.com/"
					data: "bar"

				# Send request to background.
				app.ajax.request
					method: "POST"
					url: "http://example.com/"
					data: "bar"

			it "should use sane defaults", ( done ) ->
				mimicBackgroundListener ( -> done() ),
					method: "GET"
					url: ""
					data: {}

				app.ajax.request()

#### And listens for event with response data:

			it "should capture response and pass it to callback", ( done ) ->
				# Will be called by app.ajax as a callback.
				callback = ( response, requestData ) ->
					response.should.equal "foo"
					requestData.response.should.equal "foo"
					requestData.method.should.equal "GET"
					requestData.url.should.equal "http://example.com/"
					done()

				# Set up a background listener.
				mimicBackgroundListener ( requestData ) ->
					requestData._responseId = requestData._requestId
					requestData.response = "foo"
					window.postMessage requestData, "*"

				# Send request to background and call callback on response.
				app.ajax.request
					url: "http://example.com/"
					callback: callback
