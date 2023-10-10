module cache

import time

struct Person {
	name    string
	age     int
	address string
}

fn test_cache() {
	mut cacher := new()

	mut table := cacher.table('test')

	table.set_item_callback(fn (item voidptr, typ string) {
		match typ {
			'string' {
				mut typ := unsafe { &CacheItem[string](item) }
				println(typ.key())
			}
			'int' {
				mut typ := unsafe { &CacheItem[int](item) }
				println(typ.key())
			}
			// 'cache.Person' {
			// 	mut it := unsafe { &CacheItem[Person](item) }
			// 	println(it.data())
			// }
			else {
				println('unknown type: ${typ}')
			}
		}
	})

	table.add('name', 'cache', time.second * 3)
	table.add('number', 10, time.second * 3)
	table.add('person', Person{ name: 'John', age: 30, address: 'CN' }, time.second)
	// table.add('p_person', &Person{name: "John1", age: 30, address: "CN"}, time.second) // not supported  error: initializing 'cache__Person *' (aka 'struct cache__Person *') with an expression of incompatible type 'cache__Person'

	assert table.exists('name')

	mut val := table.value[string]('name')!
	assert val != unsafe { nil }

	assert val.data() == 'cache'
	val.set_data('world')
	assert val.data() == 'world'

	mut val1 := table.value[string]('name')!
	assert val1.data() == 'world'
	assert ptr_str(val1) == ptr_str(val)

	table.value[int]('name') or {
		eprintln('${err}')
		assert err.msg().contains('&CacheItem[int]')
	}

	table.value[string]('name') or {
		println('${err}')
		assert err.msg().contains('&CacheItem[string]')
		panic(err)
	}
}
