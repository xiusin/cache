module cache

import sync
import time

const err_key_not_found = error('Key not found in cache')

[heap; noinit]
pub struct CacheTable {
	sync.RwMutex
mut:
	name             string
	items            map[string]voidptr = map[string]voidptr{}
	cleanup_timer    time.Time     = time.now()
	cleanup_interval time.Duration = time.second * 30
	add_item_after   []fn (voidptr, string)
}

pub fn (mut ct CacheTable) count() int {
	ct.@rlock()
	defer {
		ct.runlock()
	}

	return ct.items.len
}

pub fn (mut ct CacheTable) exists(key string) bool {
	ct.@rlock()
	defer {
		ct.runlock()
	}
	return key in ct.items
}

fn (mut ct CacheTable) add_internal[T](mut item CacheItem[T]) &CacheItem[T] {
	ct.@lock()
	defer {
		ct.unlock()
	}

	ct.items[item.key] = item

	for callback in ct.add_item_after {
		callback(item, T.name)
	}

	if item.ttl > 0 && (ct.cleanup_interval == 0 || item.ttl < ct.cleanup_interval) {
		ct.expiration_check()
	}

	return item
}

pub fn (mut ct CacheTable) expiration_check() {
	// auto start ticker
}

pub fn (mut ct CacheTable) add[T](key string, data T, ttl time.Duration) &CacheItem[T] {
	mut item := new_cache_item[T](key, data, ttl)
	return ct.add_internal[T](mut item)
}

pub fn (mut ct CacheTable) value[T](key string) !&CacheItem[T] {
	ct.@rlock()
	if key in ct.items {
		mut item := unsafe { &CacheItem[T](ct.items[key]) }
		if !item.init {
			return error('${key} value convert to &CacheItem[${T.name}] failed')
		}

		item.keep_alive()
		return item
	}
	ct.runlock()
	return cache.err_key_not_found
}

fn (mut ct CacheTable) set_item_callback(f fn (voidptr, string)) {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.add_item_after = []
	ct.add_item_after << f
}

fn (mut ct CacheTable) add_item_callback(f fn (voidptr, string)) {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.add_item_after << f
}

fn (mut ct CacheTable) clear_item_callback() {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.add_item_after = []
}
