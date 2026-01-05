
import redis
r = redis.from_url("rediss://default:AUiVAAIncDJjYWQ5YmVhOWE2NDY0NGJkYTNhNDYxNjNkYjNiYWMzYnAyMTg1ODE@guiding-reptile-18581.upstash.io:6379", decode_responses=True)
print("Clearing all keys...")
r.flushall()
print("Done.")
