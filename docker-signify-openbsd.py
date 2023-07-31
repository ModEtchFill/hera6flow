import time

def curTime(resolution,now=None):
	if now == None:
		now=time.time()

	if resolution >= 365 * 24 * 3600:
		fmt='%Y'
	elif resolution >= 28 * 24 * 3600:
		fmt='%Y%m'
	elif resolution >= 24 * 3600:
		fmt='%Y%m%d'
	elif resolution >= 3600:
		fmt='%Y%m%d-%H'
	elif resolution >= 60:
		fmt='%Y%m%d-%H%M'
	else: #elif resolution >= 1:
		fmt='%Y%m%d-%H%M%S'

	out = time.strftime(fmt, time.gmtime(now))

	fracSec = now-int(now)
	if resolution < 1:
		out += str(fracSec)[1:]

	return out
	

def nextTime(resolution, now=None):
	if now == None:
		now=time.time()
	incr=resolution * .8 + 0.1
	prev=curTime(resolution, now)
	while True:
		now += incr
		new = curTime(resolution, now)
		if prev != new:
			break
		incr *= 1.3
	return new

import sys
def main():
	resolution=sys.argv[1]
	try:
		resolution=float(resolution)
	except Exception as e:
		pass
	print(curTime(resolution))
	print(nextTime(resolution))


if __name__=="__main__":
	main()
