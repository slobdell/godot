/* native/trig/trig_check.c (round 39, N4): the evidence that the same float trig runs on every machine.
 *
 *   trig_check compare   cr_<f> (CORE-MATH, vendored) against THIS machine's libm <f>, every one of the 2^32 inputs for
 *                        acosf asinf atanf tanf, and ATAN2_SAMPLES pairs for atan2f: the count of different results.
 *                        On glibc >= 2.41 (CORE-MATH inside) it must be 0; on 2.39 it says how far the laptop is off.
 *   trig_check digest    one 64-bit digest of every output, per function: the system's float functions the engine and
 *                        native import (sinf cosf sincosf expf logf powf and the five trig) and the cr_ five. The same
 *                        digest on two machines = the same results there, input for input.
 *
 *   trig_check bench     ns a call, one thread, sys v cr (the preload's cost on this machine).
 *
 * A NaN result counts as one value (its sign and payload are not compared): the sim never reads one. Exhaustive runs use
 * every thread (TRIG_THREADS overrides). Build: `make trig-check` (mk/native.mk). */
#define _GNU_SOURCE
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

float cr_atan2f(float, float);
float cr_acosf(float);
float cr_asinf(float);
float cr_atanf(float);
float cr_tanf(float);

typedef float (*f1)(float);
typedef float (*f2)(float, float);

static float sys_sinc(float x) { float s, c; sincosf(x, &s, &c); return s; }
static float sys_sinc_cos(float x) { float s, c; sincosf(x, &s, &c); return c; }
/* Call through volatile pointers so the compiler cannot fold or inline a libm call into a builtin. */
static f1 volatile sys_acosf = acosf, sys_asinf = asinf, sys_atanf = atanf, sys_tanf = tanf, sys_sinf = sinf,
	sys_cosf = cosf, sys_expf = expf, sys_logf = logf;
static f2 volatile sys_atan2f = atan2f, sys_powf = powf;

static uint32_t bits(float f) { uint32_t u; if (f != f) return 0x7fc00000u; memcpy(&u, &f, 4); return u; }
static float flt(uint32_t u) { float f; memcpy(&f, &u, 4); return f; }
static uint64_t mix(uint64_t z) {  /* splitmix64's finaliser: order-free sums of mixed (input, output) pairs */
	z += 0x9e3779b97f4a7c15ull; z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9ull; z = (z ^ (z >> 27)) * 0x94d049bb133111ebull;
	return z ^ (z >> 31);
}
static uint64_t rng(uint64_t *s) { *s ^= *s << 13; *s ^= *s >> 7; *s ^= *s << 17; return *s; }

/* A pair for a two-argument function: half uniform bit patterns, half "game-like" values (|v| < 4096, either sign). */
static void pair(uint64_t *s, float *a, float *b) {
	uint64_t r = rng(s);
	if (r & 1) { *a = flt((uint32_t)(r >> 1)); *b = flt((uint32_t)rng(s)); return; }
	*a = (float)((int64_t)(rng(s) % 16777216) - 8388608) / 2048.0f * (float)((r >> 8) % 7 + 1) / 4.0f;
	*b = (float)((int64_t)(rng(s) % 16777216) - 8388608) / 2048.0f * (float)((r >> 16) % 7 + 1) / 4.0f;
}

typedef struct { const char *name; f1 a, b; f2 a2, b2; } job_t;  /* compare: a v b; digest: a alone */
typedef struct { const job_t *job; uint64_t lo, hi, diff, digest; float wx, wy, wa, wb; } part_t;

static void *run1(void *p_) {
	part_t *p = p_;
	for (uint64_t i = p->lo; i < p->hi; i++) {
		float x = flt((uint32_t)i), ra = p->job->a(x);
		p->digest += mix(i ^ ((uint64_t)bits(ra) << 32));
		if (p->job->b) {
			float rb = p->job->b(x);
			if (bits(ra) != bits(rb)) { if (!p->diff) { p->wx = x; p->wa = ra; p->wb = rb; } p->diff++; }
		}
	}
	return NULL;
}

static void *run2(void *p_) {
	part_t *p = p_;
	for (uint64_t i = p->lo; i < p->hi; i++) {
		/* The pair is a function of i alone (a counter-based draw), so the sample, and the digest, are the same at any
		 * thread count (the first version seeded per thread: 4 threads on builder0 v 8 on the laptop drew different pairs). */
		uint64_t s = mix(i ^ 0x2545f4914f6cdd1dull) | 1;
		float x, y, ra; pair(&s, &y, &x);
		ra = p->job->a2(y, x);
		p->digest += mix(((uint64_t)bits(y) << 32 | bits(x)) ^ mix(bits(ra)));
		if (p->job->b2) {
			float rb = p->job->b2(y, x);
			if (bits(ra) != bits(rb)) { if (!p->diff) { p->wy = y; p->wx = x; p->wa = ra; p->wb = rb; } p->diff++; }
		}
	}
	return NULL;
}

static void go(const job_t *job, uint64_t n, int two) {
	long t = getenv("TRIG_THREADS") ? atol(getenv("TRIG_THREADS")) : sysconf(_SC_NPROCESSORS_ONLN);
	if (t < 1) t = 1;
	if (t > 256) t = 256;
	pthread_t th[256]; part_t parts[256];
	for (long k = 0; k < t; k++) {  /* the split is by thread count, but the digest is a sum: it does not depend on it */
		parts[k] = (part_t){ job, n * k / t, n * (k + 1) / t, 0, 0, 0, 0, 0, 0 };
		pthread_create(&th[k], NULL, two ? run2 : run1, &parts[k]);
	}
	uint64_t diff = 0, digest = 0; part_t *w = NULL;
	for (long k = 0; k < t; k++) {
		pthread_join(th[k], NULL);
		diff += parts[k].diff; digest += parts[k].digest;
		if (parts[k].diff && !w) w = &parts[k];
	}
	if (job->b || job->b2) {
		printf("TRIG_COMPARE %-8s inputs %llu differ %llu", job->name, (unsigned long long)n, (unsigned long long)diff);
		if (w && two) printf(" (first: %a, %a -> cr %a, libm %a)", w->wy, w->wx, w->wa, w->wb);
		else if (w) printf(" (first: %a -> cr %a, libm %a)", w->wx, w->wa, w->wb);
		printf("\n");
	} else {
		printf("TRIG_DIGEST %-14s inputs %llu digest %016llx\n", job->name, (unsigned long long)n, (unsigned long long)digest);
	}
	fflush(stdout);
}

static float cr_atan2f_(float y, float x) { return cr_atan2f(y, x); }
static float sys_atan2f_(float y, float x) { return sys_atan2f(y, x); }
static float sys_powf_(float y, float x) { return sys_powf(y, x); }
#define W(f) static float w_##f(float x) { return f(x); }
W(sys_acosf) W(sys_asinf) W(sys_atanf) W(sys_tanf) W(sys_sinf) W(sys_cosf) W(sys_expf) W(sys_logf)

int main(int argc, char **argv) {
	const char *mode = argc > 1 ? argv[1] : "compare";
	uint64_t all = 1ull << 32, pairs = getenv("ATAN2_SAMPLES") ? strtoull(getenv("ATAN2_SAMPLES"), NULL, 10) : 400000000ull;
	if (getenv("TRIG_EXHAUSTIVE")) all = strtoull(getenv("TRIG_EXHAUSTIVE"), NULL, 10);  /* a smoke: the first N inputs */
	if (!strcmp(mode, "compare")) {
		const job_t j[] = { {"acosf", cr_acosf, w_sys_acosf, 0, 0}, {"asinf", cr_asinf, w_sys_asinf, 0, 0},
			{"atanf", cr_atanf, w_sys_atanf, 0, 0}, {"tanf", cr_tanf, w_sys_tanf, 0, 0} };
		for (unsigned k = 0; k < 4; k++) go(&j[k], all, 0);
		const job_t a = {"atan2f", 0, 0, cr_atan2f_, sys_atan2f_};
		go(&a, pairs, 1);
		return 0;
	}
	if (!strcmp(mode, "digest")) {
		const job_t j[] = { {"sys_sinf", w_sys_sinf, 0, 0, 0}, {"sys_cosf", w_sys_cosf, 0, 0, 0},
			{"sys_sincosf.s", sys_sinc, 0, 0, 0}, {"sys_sincosf.c", sys_sinc_cos, 0, 0, 0},
			{"sys_expf", w_sys_expf, 0, 0, 0}, {"sys_logf", w_sys_logf, 0, 0, 0},
			{"sys_acosf", w_sys_acosf, 0, 0, 0}, {"sys_asinf", w_sys_asinf, 0, 0, 0},
			{"sys_atanf", w_sys_atanf, 0, 0, 0}, {"sys_tanf", w_sys_tanf, 0, 0, 0},
			{"cr_acosf", cr_acosf, 0, 0, 0}, {"cr_asinf", cr_asinf, 0, 0, 0},
			{"cr_atanf", cr_atanf, 0, 0, 0}, {"cr_tanf", cr_tanf, 0, 0, 0} };
		if (!getenv("TRIG_ONLY_PAIRS"))
			for (unsigned k = 0; k < sizeof j / sizeof j[0]; k++) go(&j[k], all, 0);
		const job_t t2[] = { {"sys_atan2f", 0, 0, sys_atan2f_, 0}, {"sys_powf", 0, 0, sys_powf_, 0},
			{"cr_atan2f", 0, 0, cr_atan2f_, 0} };
		for (unsigned k = 0; k < 3; k++) go(&t2[k], pairs, 1);
		return 0;
	}
	if (!strcmp(mode, "bench")) {  /* ns a call, one thread, game-like inputs: the cost of the preload v this libm */
		struct { const char *name; f1 a; } b1[] = { {"sys_acosf", w_sys_acosf}, {"cr_acosf", cr_acosf}, {"sys_atanf", w_sys_atanf},
			{"cr_atanf", cr_atanf}, {"sys_tanf", w_sys_tanf}, {"cr_tanf", cr_tanf} };
		const uint64_t n = 50000000;
		for (unsigned k = 0; k < 6; k++) {
			struct timespec t0, t1; volatile float sink = 0; float acc = 0;
			clock_gettime(CLOCK_MONOTONIC, &t0);
			for (uint64_t i = 0; i < n; i++) acc += b1[k].a((float)(int64_t)(i % 2000001 - 1000000) * 1e-6f);
			clock_gettime(CLOCK_MONOTONIC, &t1); sink = acc; (void)sink;
			printf("TRIG_BENCH %-10s %.2f ns/call\n", b1[k].name, ((t1.tv_sec - t0.tv_sec) * 1e9 + (t1.tv_nsec - t0.tv_nsec)) / n);
		}
		f2 b2[] = { sys_atan2f_, cr_atan2f_ }; const char *b2n[] = { "sys_atan2f", "cr_atan2f" };
		for (unsigned k = 0; k < 2; k++) {
			struct timespec t0, t1; volatile float sink = 0; float acc = 0;
			clock_gettime(CLOCK_MONOTONIC, &t0);
			for (uint64_t i = 0; i < n; i++) acc += b2[k]((float)(int64_t)(i % 4001 - 2000), (float)(int64_t)(i % 3989 - 1994) + 0.5f);
			clock_gettime(CLOCK_MONOTONIC, &t1); sink = acc; (void)sink;
			printf("TRIG_BENCH %-10s %.2f ns/call\n", b2n[k], ((t1.tv_sec - t0.tv_sec) * 1e9 + (t1.tv_nsec - t0.tv_nsec)) / n);
		}
		return 0;
	}
	fprintf(stderr, "usage: trig_check compare|digest|bench\n");
	return 2;
}
