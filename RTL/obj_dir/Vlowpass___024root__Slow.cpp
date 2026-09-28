// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vlowpass.h for the primary calling header

#include "Vlowpass__pch.h"

void Vlowpass___024root___ctor_var_reset(Vlowpass___024root* vlSelf);

Vlowpass___024root::Vlowpass___024root(Vlowpass__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vlowpass___024root___ctor_var_reset(this);
}

void Vlowpass___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vlowpass___024root::~Vlowpass___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
