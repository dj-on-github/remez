// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vlowpass__pch.h"

//============================================================
// Constructors

Vlowpass::Vlowpass(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vlowpass__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , resetn{vlSymsp->TOP.resetn}
    , din_strb{vlSymsp->TOP.din_strb}
    , dout_strb{vlSymsp->TOP.dout_strb}
    , din{vlSymsp->TOP.din}
    , dout{vlSymsp->TOP.dout}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vlowpass::Vlowpass(const char* _vcname__)
    : Vlowpass(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vlowpass::~Vlowpass() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vlowpass___024root___eval_debug_assertions(Vlowpass___024root* vlSelf);
#endif  // VL_DEBUG
void Vlowpass___024root___eval_static(Vlowpass___024root* vlSelf);
void Vlowpass___024root___eval_initial(Vlowpass___024root* vlSelf);
void Vlowpass___024root___eval_settle(Vlowpass___024root* vlSelf);
void Vlowpass___024root___eval(Vlowpass___024root* vlSelf);

void Vlowpass::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vlowpass::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vlowpass___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vlowpass___024root___eval_static(&(vlSymsp->TOP));
        Vlowpass___024root___eval_initial(&(vlSymsp->TOP));
        Vlowpass___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vlowpass___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vlowpass::eventsPending() { return false; }

uint64_t Vlowpass::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vlowpass::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vlowpass___024root___eval_final(Vlowpass___024root* vlSelf);

VL_ATTR_COLD void Vlowpass::final() {
    Vlowpass___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vlowpass::hierName() const { return vlSymsp->name(); }
const char* Vlowpass::modelName() const { return "Vlowpass"; }
unsigned Vlowpass::threads() const { return 1; }
void Vlowpass::prepareClone() const { contextp()->prepareClone(); }
void Vlowpass::atClone() const {
    contextp()->threadPoolpOnClone();
}
