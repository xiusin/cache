module cache

import sync
import time
import log

const err_key_not_found = error('Key not found in cache')

[heap; noinit]
pub struct CacheTable {
	sync.RwMutex
mut:
	max_table_key int
	name          string
	// 目前发现如果高速插入数据会导致频繁扩容，GC侧导致读取item失败而崩溃
	// If there are too many keys, it may potentially cause a memory leak. Optimization is needed。
	// GC Warning: Repeated allocation of very large block (appr. size 6860800): May lead to memory leak and poor performance
	items            shared map[string]&CacheItem = map[string]&CacheItem{}
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

fn (mut ct CacheTable) add_internal(mut item CacheItem) !&CacheItem {
	ct.@lock()
	ct.items[item.key] = item
	ct.unlock()

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
		ct.@lock()
		mut expire_keys := []string{cap: 1024}
		for key, item in ct.items {
			if item != unsafe { nil } {
				if item.ttl > 0 && item.expired() {
					expire_keys << key
				}
			}
		}
		for key in expire_keys {
			ct.delete_internal(key) or {}
		}
		ct.unlock()
	}
}

pub fn (mut ct CacheTable) delete(key string) ! {
	ct.@lock()
	ct.delete_internal(key)!
	ct.unlock()
}

[manualfree]
fn (mut ct CacheTable) delete_internal(key string) ! {
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

	ct.items.delete(key)
	item.mutex.@rlock()
	for callback in item.remove_expire_fn {
		callback(item)
	}
	item.mutex.runlock()
}

pub fn (mut ct CacheTable) add[T](key string, data T, ttl time.Duration) !&CacheItem[T] {
	mut item := new_cache_item[T](key, &data, ttl)
	return ct.add_internal(mut item)!
}

pub fn (mut ct CacheTable) not_found_add[T](key string, data T, ttl time.Duration) bool {
	ct.@lock()
	defer {
		ct.unlock()
	}

	if key in ct.items {
		return true
	}

	if ct.max_table_key > 0 && ct.items.len >= ct.max_table_key {
		return false
	}

	mut item := new_cache_item[T](key, &data, ttl)
	_ = ct.add_internal(mut item) or { return false }
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
