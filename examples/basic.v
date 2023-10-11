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
	user.add('name', 'xiusin', time.second)!

	// Let's retrieve the item from the cache.
	mut res := user.value('name') or {
		eprintln('Error retrieving value from cache: ${err}')
		return
	}
	println('Found value in cache: ${res.string()!}')

	// Wait for the item to expire in cache.
	time.sleep(6 * time.second)
	if user.exists('xiusin') {
		eprintln('Item is not cached or expired.')
	}

	// Add another item that never expires.
	user.add('info', Info{ address: 'china' }, 0)!
	println(user.value('info')!.json[Info]()!)
	// Remove the item from the cache.
	user.delete('info')!
	// And wipe the entire cache table.
	user.flush()
}
