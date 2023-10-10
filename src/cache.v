module cache

import sync

pub struct Cache {
	sync.RwMutex
mut:
	caches map[string]&CacheTable = map[string]&CacheTable{}
}

pub fn new() &Cache {
	return &Cache{}
}

pub fn (mut c Cache) table(table string) &CacheTable {
	c.@lock()
	defer {
		c.unlock()
	}

	if table !in c.caches {
		c.caches[table] = &CacheTable{
			name: table
		}
	}

	return unsafe { c.caches[table] }
}
