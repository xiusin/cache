module main

import xiusin.cache
import time
import rand
import benchmark
import log

fn main() {
	mut bench := benchmark.start()
	mut i := 0
	mut cache_manager := cache.new(cleanup_interval: time.second * 10)
	mut user := cache_manager.table('user')!
	user.set_logger(log.new_thread_safe_log())
	for {
		if i > 1000000 {
			break
		}
		user.add('user_${i}', 'user_${i}', 0)!
		i++
	}
	rest1 := bench.measure('cache insert')
	println('pre insert action use: ${time.Duration(rest1 / 1000000).str()}')
}
