module cache

import sync
import time
import log

const err_key_not_found = error('Key not found in cache')

[heap; noinit]
pub struct CacheTable {
	sync.RwMutex
mut:
	name             string
	items            map[string]&CacheItem = map[string]&CacheItem{}
	cleanup_timer    time.Time     = time.now()
	cleanup_interval time.Duration = time.second
	add_item_after   []fn (&CacheItem)
	logger           &log.ThreadSafeLog = unsafe { nil }
}

pub fn (mut ct CacheTable) set_logger(logger &log.ThreadSafeLog) {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.logger = unsafe { logger }
}

pub fn (mut ct CacheTable) log(message string) {
	if unsafe { ct.logger != nil } {
		ct.logger.info(message)
	}
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

fn (mut ct CacheTable) add_internal(mut item CacheItem) &CacheItem {
	ct.@lock()
	defer {
		ct.unlock()
	}

	ct.items[item.key] = item
	ct.log('Adding item with key ${item.key} and lifespan of ${item.ttl} to table ${ct.name}')

	for callback in ct.add_item_after {
		callback(item)
	}

	return item
}

pub fn (mut ct CacheTable) expiration_check() {
	if ct.cleanup_interval < time.second {
		ct.cleanup_interval = time.second
	}

	mut expire_keys := []string{}
	for {
		time.sleep(ct.cleanup_interval)
		ct.@lock()

		for key, item in ct.items { // Exception: EXC_BAD_ACCESS (code=1, address=0xf8)
			if unsafe { item == nil } || item.ttl == 0 {
				continue
			}
			if item.expired() {
				expire_keys << key
			}
		}

		for key in expire_keys {
			ct.delete_internal(key) or {}
		}
		unsafe { expire_keys.reset() }
		ct.unlock()
	}
}

pub fn (mut ct CacheTable) delete(key string) ! {
	ct.@lock()
	ct.delete_internal(key)!
	ct.unlock()
}

fn (mut ct CacheTable) delete_internal(key string) ! {
	if key !in ct.items {
		return cache.err_key_not_found
	}
	mut item := unsafe { ct.items[key] }
	if unsafe { item == nil } {
		return cache.err_key_not_found
	}
	item.@rlock()
	defer {
		item.runlock()
	}
	ct.items.delete(key)
	ct.log('Deleting item with key ${key} created on ${item.created_on} and hit ${item.access_count} times from table ${ct.name}')
	for callback in item.remove_expire_fn {
		callback(item)
	}
}

pub fn (mut ct CacheTable) add[T](key string, data T, ttl time.Duration) &CacheItem[T] {
	mut item := new_cache_item[T](key, &data, ttl)
	return ct.add_internal(mut item)
}

pub fn (mut ct CacheTable) not_found_add[T](key string, data T, ttl time.Duration) bool {
	ct.@lock()
	defer {
		ct.unlock()
	}

	if key in ct.items {
		return true
	}

	mut item := new_cache_item[T](key, &data, ttl)
	_ = ct.add_internal(mut item)
	return true
}

// flush deletes all items from this cache table.
pub fn (mut ct CacheTable) flush() {
	ct.@lock()
	ct.logger.info('Flushing table ${ct.name}.')
	for key, _ in ct.items {
		ct.items.delete(key)
	}
	ct.items.clear()
	ct.unlock()
}

pub fn (mut ct CacheTable) value(key string) !&CacheItem {
	ct.@rlock()
	defer {
		ct.runlock()
	}

	if key in ct.items {
		mut item := unsafe { ct.items[key] }
		if !item.expired() {
			item.keep_alive()
			return item
		}
	}

	return cache.err_key_not_found
}

pub fn (mut ct CacheTable) set_item_callback(f fn (&CacheItem)) {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.add_item_after = []
	ct.add_item_after << f
}

pub fn (mut ct CacheTable) add_item_callback(f fn (&CacheItem)) {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.add_item_after << f
}

pub fn (mut ct CacheTable) clear_item_callback() {
	ct.@lock()
	defer {
		ct.unlock()
	}
	ct.add_item_after = []
}

pub fn (mut ct CacheTable) iter(callback fn (&CacheItem)) {
	ct.@rlock()
	for _, v in ct.items {
		callback(v)
	}
	ct.runlock()
}

struct ItemCount {
	key   string
	count u64
}

pub fn (mut ct CacheTable) top_accessed(count i64) []&CacheItem {
	ct.@rlock()
	mut item_count_arr := []ItemCount{len: ct.items.len}
	for _, item in ct.items {
		if unsafe { item == nil } {
			continue
		}
		item_count_arr << ItemCount{
			key: item.key
			count: item.access_count
		}
	}
	item_count_arr.sort(b.count < a.count)
	item_count_arr = item_count_arr[0..count].clone()
	mut items := []&CacheItem{}
	for item in item_count_arr {
		value := unsafe { ct.items[item.key] }
		if unsafe { value != nil } {
			items << value
		}
	}

	ct.runlock()
	return items
}
