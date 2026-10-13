#pragma once
int td_create_client_id();
void td_send(int, const char*);
const char* td_receive(double);
const char* td_execute(const char*);
