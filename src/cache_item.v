module cache

import sync
import time
import json
import v.reflection

pub interface CacheItemInterface {
	ttl() time.Duration
	last_accessed_on() time.Time
}

// JSON library is unable to directly decode/encode the resulting string. Therefore, this structure is built-in to handle such cases.
[noinit]
pub struct CacheData[T] {
	data T
}

[heap; noinit]
pub struct CacheItem {
mut:
	mutex            &sync.RwMutex = sync.new_rwmutex()
	key              string
	data             []u8
	ttl              time.Duration
	created_on       time.Time
	last_accessed_on time.Time
	access_count     u64
	remove_expire_fn []fn (&CacheItem)
	type_id          int
}

[manualfree]
fn new_cache_item[T](key string, data T, ttl time.Duration) &CacheItem {
	now := time.now()
	encode_data := json.encode(CacheData[T]{ data: data })
	defer {
		unsafe {
			encode_data.free()
		}
	}
	return &CacheItem{
		key: key
		ttl: ttl
		created_on: now
		last_accessed_on: now
		access_count: 0
		remove_expire_fn: []
		type_id: T.idx
		data: encode_data.bytes()
	}
}

fn (item CacheItem) expired() bool {
	if item.ttl == 0 {
		return false
	}

	return time.since(item.last_accessed_on) >= item.ttl
}

fn (mut item CacheItem) keep_alive() {
	item.mutex.@lock()
	defer {
		item.mutex.unlock()
	}

	item.last_accessed_on = time.now()
	item.access_count++
}

pub fn (item CacheItem) ttl() time.Duration {
	return item.ttl
}

pub fn (item CacheItem) created_on() time.Time {
	return item.created_on
}

pub fn (item CacheItem) last_accessed_on() time.Time {
	return item.last_accessed_on
}

pub fn (item CacheItem) access_count() u64 {
	return item.access_count
}

pub fn (item CacheItem) key() string {
	return item.key
}

pub fn (item CacheItem) data() []u8 {
	return item.data
}

pub fn (mut item CacheItem) set_remove_expire_fn(f fn (&CacheItem)) {
	item.mutex.@lock()
	defer {
		item.mutex.unlock()
	}
	item.remove_expire_fn = []
	item.remove_expire_fn << f
}

pub fn (mut item CacheItem) add_remove_expire_fn(f fn (&CacheItem)) {
	item.mutex.@lock()
	defer {
		item.mutex.unlock()
	}
	item.remove_expire_fn << f
}

pub fn (mut item CacheItem) clear_remove_expire_fn() {
	item.mutex.@lock()
	defer {
		item.mutex.unlock()
	}
	item.remove_expire_fn = []
}

pub fn (mut item CacheItem) string() !string {
	return item.json[string]()!
}

pub fn (item CacheItem) json[T]() !T {
	// Why record type_id? Because currently, the JSON standard library does not throw an error when parsing a generic type incorrectly.
	if item.type_id != T.idx {
		return error('type error, type is: ${reflection.type_name(item.type_id)}')
	}
	return json.decode(CacheData[T], item.data.bytestr())!.data
}

pub fn (item CacheItem) origin_data() string {
	return item.data.bytestr()
}
