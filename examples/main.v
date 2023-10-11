module main

import xiusin.cache
import time
import rand
import benchmark

fn main() {
	mut cache_manager := cache.new(cleanup_interval: time.second)

	mut user := cache_manager.table('user')!

	// user.set_logger(log.new_thread_safe_log())

	mut bench := benchmark.start()

	spawn fn [mut user] () ! {
		mut i := 0
		for {
			if i > 500000 {
				break
			}
			user.add('user_${i}', i, time.second * rand.intn(10)!) or {}
			i++
		}
	}()

	mut i := 500000
	for {
		if i > 1000000 {
			break
		}
		user.add('user_${i}', i, time.second * rand.intn(10)!)!
		i++
	}

	bench.measure('insert')
}
