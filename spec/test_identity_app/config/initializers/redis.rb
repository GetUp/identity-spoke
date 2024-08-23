$redis = ConnectionPool::Wrapper.new(size: Settings.redis.pool_size, timeout: 3) { Redis.new(url: Settings.redis_url) }
