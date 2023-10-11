module main

import xiusin.cache
import time
import rand
import benchmark
import log

fn main() {
	mut cache_manager := cache.new(cleanup_interval: time.second * 10)
	mut user := cache_manager.table('user')!
	user.set_logger(log.new_thread_safe_log())

	mut bench := benchmark.start()
	mut i := 0
	for {
		if i > 500000 {
			break
		}
		user.add('user_${i}', i, time.second * rand.intn(10)!)!
		i++
	}

	rest := bench.measure('insert')
	println('pre insert action use: ${time.Duration(rest / 1000000).str()}')
}
