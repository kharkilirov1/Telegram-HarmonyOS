#pragma once
struct uv_loop_s {};
using uv_loop_t = uv_loop_s;
struct uv_work_s { void* data; };
using uv_work_t = uv_work_s;
int uv_queue_work(uv_loop_t*, uv_work_t*, void (*)(uv_work_t*), void (*)(uv_work_t*, int));
