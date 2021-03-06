package sync

import "core:sys/win32"

foreign {
	@(link_name="llvm.x86.sse2.pause")
	yield_processor :: proc() ---
}

Semaphore :: struct {
	_handle: win32.Handle,
}

Mutex :: struct {
	_critical_section: win32.Critical_Section,
}

Condition :: struct {
	event: win32.Handle,
}

Ticket_Mutex :: struct {
	ticket:  u64,
	serving: u64,
}


current_thread_id :: proc() -> i32 {
	return i32(win32.get_current_thread_id());
}

semaphore_init :: proc(s: ^Semaphore) {
	s._handle = win32.create_semaphore_w(nil, 0, 1<<31-1, nil);
}

semaphore_destroy :: proc(s: ^Semaphore) {
	win32.close_handle(s._handle);
}

semaphore_post :: proc(s: ^Semaphore, count: int) {
	win32.release_semaphore(s._handle, i32(count), nil);
}

semaphore_release :: inline proc(s: ^Semaphore) {
	semaphore_post(s, 1);
}

semaphore_wait :: proc(s: ^Semaphore) {
	result := win32.wait_for_single_object(s._handle, win32.INFINITE);
	assert(result != win32.WAIT_FAILED);
}


mutex_init :: proc(m: ^Mutex, spin_count := 0) {
	win32.initialize_critical_section_and_spin_count(&m._critical_section, u32(spin_count));
}

mutex_destroy :: proc(m: ^Mutex) {
	win32.delete_critical_section(&m._critical_section);
}

mutex_lock :: proc(m: ^Mutex) {
	win32.enter_critical_section(&m._critical_section);
}

mutex_try_lock :: proc(m: ^Mutex) -> bool {
	return bool(win32.try_enter_critical_section(&m._critical_section));
}

mutex_unlock :: proc(m: ^Mutex) {
	win32.leave_critical_section(&m._critical_section);
}


condition_init :: proc(using c: ^Condition) {
	event = win32.create_event_w(nil, false, false, nil);
	assert(event != nil);
}

condition_signal :: proc(using c: ^Condition) {
	ok := win32.set_event(event);
	assert(bool(ok));
}

condition_wait_for :: proc(using c: ^Condition) {
	result := win32.wait_for_single_object(event, win32.INFINITE);
	assert(result != win32.WAIT_FAILED);
}

condition_destroy :: proc(using c: ^Condition) {
	if event != nil {
		win32.close_handle(event);
	}
}


ticket_mutex_init :: proc(m: ^Ticket_Mutex) {
	atomic_store(&m.ticket,  0, Ordering.Relaxed);
	atomic_store(&m.serving, 0, Ordering.Relaxed);
}

ticket_mutex_lock :: inline proc(m: ^Ticket_Mutex) {
	ticket := atomic_add(&m.ticket, 1, Ordering.Relaxed);
	for ticket != m.serving {
		yield_processor();
	}
}

ticket_mutex_unlock :: inline proc(m: ^Ticket_Mutex) {
	atomic_add(&m.serving, 1, Ordering.Relaxed);
}
