module cache

import sync

pub struct Cache {
	sync.RwMutex
	option CacheOption
mut:
	caches map[string]&CacheTable = map[string]&CacheTable{}
}

pub fn new(option CacheOption) &Cache {
	return &Cache{
		option: option
	}
}

pub fn (mut c Cache) table(table string) !&CacheTable {
	c.@lock()
	defer {
		c.unlock()
	}

	if c.option.max_table > 0 && c.option.max_table <= c.caches.len {
		return error('The maximum number of data tables is ${c.option.max_table}')
	}

	if table !in c.caches {
		mut cache_table := &CacheTable{
			name: table
			cleanup_interval: c.option.cleanup_interval
		}
		c.caches[table] = cache_table
		spawn cache_table.expiration_check()
	}

	return unsafe { c.caches[table] }
}
