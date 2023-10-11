module cache

import time

struct Person {
	name    string
	age     int
	address string
}

fn test_cache() ! {
	mut cacher := new()

	mut table := cacher.table('test')!

	table.set_item_callback(fn (mut item CacheItem) {
		// dump("${item.key} - ${item.data().bytestr()}")
	})

	table.add('name', 'cache', time.second * 3)!
	table.add('number', 10, time.second * 3)!

	table.add('person', Person{ name: 'John', age: 30, address: 'CN' }, time.second)!
	// table.add('p_person', &Person{name: "John1", age: 30, address: "CN"}, time.second)! // not supported  error: initializing 'cache__Person *' (aka 'struct cache__Person *') with an expression of incompatible type 'cache__Person'

	assert table.exists('name')

	mut val := table.value('name')!
	assert val != unsafe { nil }
	assert val.json[string]()! == 'cache'
	mut val1 := table.value('name')!
	assert val.string()! == 'cache'
	assert ptr_str(val1) == ptr_str(val)

	mut person := table.value('person')!
	assert person.json[Person]()!.name == 'John'
	// assert person.json[&Person]()!.name == 'John'
	person.json[int]() or { assert err.msg().contains('Person') }
	table.delete('name')!
	assert table.exists('name') == false
	time.sleep(time.second)
	assert table.exists('person') == false

	table.not_found_add('name', 'xiusin', time.second)
	assert table.value('name')!.json[string]()! == 'xiusin'

	table.not_found_add('name', 'xiusin_modify', time.second)
	assert table.value('name')!.json[string]()! == 'xiusin'
}
