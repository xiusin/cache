module cache

import sync
import time

pub interface CacheItemInterface {
	ttl() time.Duration
	last_accessed_on() time.Time
}

[heap; noinit]
pub struct CacheItem[T] {
	sync.RwMutex
mut:
	key              string
	data             T
	ttl              time.Duration
	created_on       time.Time
	last_accessed_on time.Time
	access_count     u64
	remove_expire_fn []fn (voidptr)
	d_typ            int
	init             bool
}

fn new_cache_item[T](key string, data T, ttl time.Duration) &CacheItem[T] {
	now := time.now()

	// dump(T.name)
	// t := reflection.get_type(T.idx) or {
	// 	reflection.Type{name: 'unknown'}
	// }
	// dump(t.sym) // TODO 确认是否为指针类型

	return &CacheItem[T]{
		key: key
		data: data
		ttl: ttl
		created_on: now
		last_accessed_on: now
		access_count: 0
		remove_expire_fn: []
		d_typ: T.idx
		init: true
	}
}

fn (mut item CacheItem[T]) keep_alive() {
	item.@lock()
	defer {
		item.unlock()
	}

	item.last_accessed_on = time.now()
	item.access_count++
}

pub fn (mut item CacheItem[T]) ttl() time.Duration {
	return item.ttl
}

pub fn (mut item CacheItem[T]) created_on() time.Time {
	return item.created_on
}

pub fn (mut item CacheItem[T]) last_accessed_on() time.Time {
	return item.last_accessed_on
}

pub fn (mut item CacheItem[T]) access_count() u64 {
	item.@rlock()
	defer {
		item.runlock()
	}

	return item.access_count
}

pub fn (mut item CacheItem[T]) key() string {
	return item.key
}

pub fn (mut item CacheItem[T]) data() T {
	return item.data
}

pub fn (mut item CacheItem[T]) set_data(data T) {
	item.@lock()
	defer {
		item.unlock()
	}
	item.data = data
}

pub fn (mut item CacheItem[T]) set_remove_expire_fn(f fn (voidptr)) {
	item.@lock()
	defer {
		item.unlock()
	}
	item.remove_expire_fn = []
	item.remove_expire_fn << f
}

pub fn (mut item CacheItem[T]) add_remove_expire_fn(f fn (voidptr)) {
	item.@lock()
	defer {
		item.unlock()
	}
	item.remove_expire_fn << f
}

pub fn (mut item CacheItem[T]) clear_remove_expire_fn() {
	item.@lock()
	defer {
		item.unlock()
	}
	item.remove_expire_fn = []
}
