module cache

import time
import log

const err_key_not_found = error('key not found in cache')

[heap; noinit]
pub struct CacheTable {
mut:
	max_table_key    int
	name             string
	items            shared map[string]&CacheItem = map[string]&CacheItem{}
	cleanup_timer    time.Time     = time.now()
	cleanup_interval time.Duration = time.second
	add_item_after   []fn (&CacheItem)
	logger           &log.ThreadSafeLog = unsafe { nil }
}

pub fn (mut ct CacheTable) set_logger(logger &log.ThreadSafeLog) {
	ct.logger = unsafe { logger }
}

pub fn (mut ct CacheTable) log(message string) {
	if unsafe { ct.logger != nil } {
		ct.logger.info(message)
	}
}

pub fn (mut ct CacheTable) count() int {
	return ct.items.len
}

pub fn (mut ct CacheTable) exists(key string) bool {
	if key in ct.items {
		item := unsafe { ct.items[key] }
		if unsafe { item != nil } {
			if item.expired() {
				ct.delete(key) or {}
				return false
			}
			return true
		}
	}
	return false
}

fn (mut ct CacheTable) add_internal(mut item CacheItem) !&CacheItem {
	lock ct.items {
		ct.items[item.key] = item
	}

	for callback in ct.add_item_after {
		callback(item)
	}
	return item
}

pub fn (mut ct CacheTable) expiration_check() {
	if ct.cleanup_interval < time.second {
		ct.cleanup_interval = time.second
	}

	for {
		time.sleep(ct.cleanup_interval)
		mut expire_keys := []string{cap: 1024}
		rlock ct.items {
			for key, item in ct.items {
				if item != unsafe { nil } {
					if item.ttl > 0 && item.expired() {
						expire_keys << key
					}
				}
			}
		}

		for key in expire_keys {
			ct.delete(key) or {}
		}
		ct.log('clear expired keys: ${expire_keys.len}')
	}
}

[manualfree]
pub fn (mut ct CacheTable) delete(key string) ! {
	if key !in ct.items {
		return cache.err_key_not_found
	}
	mut item := unsafe { ct.items[key] }
	defer {
		unsafe {
			free(item)
		}
	}

	if unsafe { item == nil } {
		return cache.err_key_not_found
	}

	lock ct.items {
		ct.items.delete(key)
	}

	item.mutex.@rlock()
	for callback in item.remove_expire_fn {
		callback(item)
	}
	item.mutex.runlock()
}

[inline]
pub fn (mut ct CacheTable) add[T](key string, data T, ttl time.Duration) !&CacheItem[T] {
	mut item := new_cache_item[T](key, &data, ttl)
	return ct.add_internal(mut item)!
}

pub fn (mut ct CacheTable) not_found_add[T](key string, data T, ttl time.Duration) bool {
	if !ct.exists(key) {
		mut item := new_cache_item[T](key, &data, ttl)
		_ = ct.add_internal(mut item) or { return false }
	}
	return true
}

// flush deletes all items from this cache table.
[inline]
pub fn (mut ct CacheTable) flush() {
	lock ct.items {
		for key, _ in ct.items {
			ct.items.delete(key)
		}
		ct.items.clear()
	}
}

pub fn (mut ct CacheTable) value(key string) !&CacheItem {
	lock {
		if key in ct.items {
			mut item := unsafe { ct.items[key] }
			if !item.expired() {
				item.keep_alive()
				return item
			}
		}
	}

	return cache.err_key_not_found
}

pub fn (mut ct CacheTable) set_item_callback(f fn (&CacheItem)) {
	ct.add_item_after = []
	ct.add_item_after << f
}

pub fn (mut ct CacheTable) add_item_callback(f fn (&CacheItem)) {
	ct.add_item_after << f
}

pub fn (mut ct CacheTable) clear_item_callback() {
	ct.add_item_after = []
}

pub fn (mut ct CacheTable) iter(callback fn (&CacheItem)) {
	lock ct.items {
		for _, v in ct.items {
			callback(v)
		}
	}
}

struct ItemCount {
	key   string
	count u64
}

pub fn (mut ct CacheTable) top_accessed(count i64) []&CacheItem {
	mut items := []&CacheItem{}

	lock ct.items {
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
		for item in item_count_arr {
			value := unsafe { ct.items[item.key] }
			if unsafe { value != nil } {
				items << value
			}
		}
	}
	return items
}
