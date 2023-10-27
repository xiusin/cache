module main

import xiusin.cache
import time
import benchmark
import log

fn main() {
	mut bench := benchmark.start()
	mut cache_manager := cache.new(cleanup_interval: time.second * 10)
	mut user := cache_manager.table('user')!
	user.set_logger(log.new_thread_safe_log())
	for i in 0 .. 1000000 {
		user.add('user_${i}', 'user_${i}', 0)!
	}
	rest1 := bench.measure('cache insert')
	println('pre insert action use: ${time.Duration(rest1 / 1000000).str()}')
}
