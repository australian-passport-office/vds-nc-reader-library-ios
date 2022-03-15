//
//  Debugger.h
//  VDSNCCheckerExample
//
//  Copyright (c) 2021, Commonwealth of Australia. vds.support@dfat.gov.au
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License. You may obtain a copy
//  of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations
//  under the License.

#ifndef Debugger_h
#define Debugger_h

#include <stdio.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include <stdbool.h>
#include <sys/types.h>

void disable_gdb(void) __attribute__((always_inline));
bool isBeingDebugged_sysctl(void) __attribute__((always_inline));
#endif /* Debugger_h */
