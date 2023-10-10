module main

import xiusin.cache
import time
import rand
import log

fn main() {
	mut cache_manager := cache.new(cleanup_interval: time.second)

	mut user := cache_manager.table('user')!

	user.set_logger(log.new_thread_safe_log())

	mut i := 0
	for {
		time.sleep(time.millisecond * 300)
		user.add('user_${i}', i, time.second * rand.intn(10)!)
		// rand read
		user.value('user_${rand.intn(i) or { 0 }}') or {}
		i++

		if i % 10 == 0 {
			println('==================')
			for j, accessed in user.top_accessed(3) {
				println('top: ${j} is ${accessed.key()} count: ${accessed.access_count()}')
			}
			println('current keys: ${user.count()}')
			println('')
			println('')
			println('')
			println('')
			println('')
		}
	}
}
