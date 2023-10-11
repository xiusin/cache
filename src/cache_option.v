module cache

import time

[params]
pub struct CacheOption {
pub mut:
	cleanup_interval time.Duration = time.second
	max_table        int
	max_memory       int
	max_table_key    int
}
