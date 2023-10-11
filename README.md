# cache

[![Latest Release](https://img.shields.io/github/release/xiusin/cache.svg)](https://github.com/xiusin/cache/releases)
[![Coverage Status](https://coveralls.io/repos/github/xiusin/cache/badge.svg?branch=master)](https://coveralls.io/github/xiusin/cache?branch=master)

Concurrency-safe v caching library with expiration capabilities.

## Installation

Make sure you have a working V environment .
See the [installation instructions](https://github.com/vlang/v/blob/master/doc/docs.md#installing-v-from-source).

To install, simply run:

```
v install xiusin.cache
```

## Example
```vlang
module main

import xiusin.cache
import time

struct Info {
	pub mut:
	address string
}

fn main() {
	mut cache_manager := cache.new(cleanup_interval: time.second * 10)

	// Accessing a new cache table for the first time will create it.
	mut user := cache_manager.table('user')!

	// We will put a new item in the cache. It will expire after
	// not being accessed via Value(key) for more than 5 seconds.
	user.add("name","xiusin", time.second)!

	// Let's retrieve the item from the cache.
	mut res := user.value("name") or {
		eprintln("Error retrieving value from cache: ${err}")
		return
	}
	println("Found value in cache: ${res.string()!}")

	// Wait for the item to expire in cache.
	time.sleep(6 * time.second)
	if user.exists("xiusin") {
		eprintln("Item is not cached or expired.")
	}

	// Add another item that never expires.
	user.add("info", Info{ address: "china" }, 0)!
	println(user.value("info")!.json[Info]()!)
	// Remove the item from the cache.
	user.delete("info")!
	// And wipe the entire cache table.
	user.flush()
}


// Found value in cache: xiusin
//	Info{
//	    address: 'china'
// }
```

To run this example, go to examples/ and run:

    v run basic.go

You can find a [few more examples here](https://github.com/xiusin/cache/tree/master/examples).
Also see our test-cases in `cache_test.v` for further working examples.
