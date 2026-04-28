package middleware

import (
	"net"
	"net/http"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// IPLimiter — per-IP rate limiter. Ставится перед /login и /register
// чтобы защититься от брутфорса и спама регистраций.
//
// Старые лимитеры собираются GC через 10 минут неактивности — иначе мапа
// растёт бесконечно при большом количестве IP.
type IPLimiter struct {
	mu       sync.Mutex
	visitors map[string]*visitor
	rps      rate.Limit
	burst    int
}

type visitor struct {
	limiter *rate.Limiter
	lastSeen time.Time
}

// NewIPLimiter — rps запросов в секунду, burst — допустимый burst.
// Например NewIPLimiter(0.2, 5) = 1 запрос в 5 секунд, до 5 подряд.
func NewIPLimiter(rps rate.Limit, burst int) *IPLimiter {
	l := &IPLimiter{
		visitors: make(map[string]*visitor),
		rps:      rps,
		burst:    burst,
	}
	go l.gc()
	return l
}

func (l *IPLimiter) gc() {
	for {
		time.Sleep(time.Minute)
		l.mu.Lock()
		for ip, v := range l.visitors {
			if time.Since(v.lastSeen) > 10*time.Minute {
				delete(l.visitors, ip)
			}
		}
		l.mu.Unlock()
	}
}

func (l *IPLimiter) get(ip string) *rate.Limiter {
	l.mu.Lock()
	defer l.mu.Unlock()
	v, ok := l.visitors[ip]
	if !ok {
		v = &visitor{limiter: rate.NewLimiter(l.rps, l.burst)}
		l.visitors[ip] = v
	}
	v.lastSeen = time.Now()
	return v.limiter
}

func (l *IPLimiter) Middleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ip := clientIP(r)
		if !l.get(ip).Allow() {
			http.Error(w, "Слишком много запросов, попробуй позже", http.StatusTooManyRequests)
			return
		}
		next(w, r)
	}
}

func clientIP(r *http.Request) string {
	// За reverse-proxy уважаем X-Forwarded-For (только первый — нашему доверяем).
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// Берём первый IP.
		for i, c := range xff {
			if c == ',' {
				return xff[:i]
			}
		}
		return xff
	}
	if rip := r.Header.Get("X-Real-IP"); rip != "" {
		return rip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
