class RedisStub
  @date = '1970-01-01 00:00:00'

  def with
    yield self
  end
  def reset
    @date = '1970-01-01 00:00:00'
  end
  def get(*args)
    @date
  end
  def set(*args)
    @date = Time.now.to_s
  end
end
