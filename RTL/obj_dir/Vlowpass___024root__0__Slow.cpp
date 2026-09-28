// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vlowpass.h for the primary calling header

#include "Vlowpass__pch.h"

VL_ATTR_COLD void Vlowpass___024root___eval_static(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_static\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
}

VL_ATTR_COLD void Vlowpass___024root___eval_initial(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_initial\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VL_ATTR_COLD void Vlowpass___024root___eval_final(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_final\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vlowpass___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vlowpass___024root___eval_phase__stl(Vlowpass___024root* vlSelf);

VL_ATTR_COLD void Vlowpass___024root___eval_settle(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_settle\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VstlIterCount;
    // Body
    __VstlIterCount = 0U;
    vlSelfRef.__VstlFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VstlIterCount)))) {
#ifdef VL_DEBUG
            Vlowpass___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
#endif
            VL_FATAL_MT("lowpass.sv", 147, "", "Settle region did not converge after 100 tries");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
    } while (Vlowpass___024root___eval_phase__stl(vlSelf));
}

VL_ATTR_COLD void Vlowpass___024root___eval_triggers__stl(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_triggers__stl\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VstlTriggered
                                      [0U]) | (IData)((IData)(vlSelfRef.__VstlFirstIteration)));
    vlSelfRef.__VstlFirstIteration = 0U;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vlowpass___024root___dump_triggers__stl(vlSelfRef.__VstlTriggered, "stl"s);
    }
#endif
}

VL_ATTR_COLD bool Vlowpass___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vlowpass___024root___dump_triggers__stl(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(Vlowpass___024root___trigger_anySet__stl(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD bool Vlowpass___024root___trigger_anySet__stl(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___trigger_anySet__stl\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

VL_ATTR_COLD void Vlowpass___024root___stl_sequent__TOP__0(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___stl_sequent__TOP__0\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded;
    lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__prod = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__1__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__1__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__full = 0;
    IData/*27:0*/ lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__a = 0;
    IData/*28:0*/ lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__full;
    lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__full = 0;
    // Body
    lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000000e81ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__40__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000000542ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__39__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffe32cULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__38__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffce64ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__37__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000fffffffff112ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__36__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000002541ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__35__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000001748ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__34__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffd058ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__33__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffc73dULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__32__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x00000000000025e2ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__31__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000005d59ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__30__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000fffffffff46cULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__29__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffff78b5ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__28__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffd3ecULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__27__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000000afafULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__26__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000000928bULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__25__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffff2e4fULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__24__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000fffffffe9774ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__23__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000000e850ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__22__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000004fe20ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__21__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000070fb9ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__20__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000004fe20ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__19__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000000e850ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__18__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000fffffffe9774ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__17__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffff2e4fULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__16__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000000928bULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__15__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x000000000000afafULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__14__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffd3ecULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__13__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffff78b5ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__12__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000fffffffff46cULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__11__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000005d59ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__10__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x00000000000025e2ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__9__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffc73dULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__8__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffd058ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__7__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000001748ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__6__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000002541ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__5__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000fffffffff112ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__4__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffce64ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__3__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000ffffffffe32cULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__2__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000000542ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__1__KET____DOT__u_z__q))));
    vlSelfRef.lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__prod 
        = (0x0000ffffffffffffULL & VL_MULS_QQQ(48, 0x0000000000000e81ULL, 
                                               (0x0000ffffffffffffULL 
                                                & VL_EXTENDS_QI(48,28, vlSelfRef.din))));
    lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded 
        = (0x0000ffffffffffffULL & VL_SHIFTRS_QQI(48,48,32, 
                                                  (0x0000ffffffffffffULL 
                                                   & (0x0000000000080000ULL 
                                                      + lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__prod)), 0x00000014U));
    vlSelfRef.lowpass__DOT____Vcellout__g_mul__BRA__0__KET____DOT__u_mul__dout 
        = (VL_LTS_IQQ(48, 0x0000000007ffffffULL, lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded)
            ? 0x07ffffffU : (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded)
                              ? 0x08000000U : (0x0fffffffU 
                                               & (IData)(lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded))));
    vlSelfRef.lowpass__DOT__acc[0U] = vlSelfRef.lowpass__DOT____Vcellout__g_mul__BRA__0__KET____DOT__u_mul__dout;
    lowpass__DOT__g_sum__BRA__1__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, vlSelfRef.lowpass__DOT____Vcellout__g_mul__BRA__0__KET____DOT__u_mul__dout) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__1__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__1__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__1__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[1U] = lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__2__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[2U] = lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__3__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[3U] = lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__4__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[4U] = lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__5__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[5U] = lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__6__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[6U] = lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__7__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[7U] = lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__8__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[8U] = lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__9__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[9U] = lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__10__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000000aU] = lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__11__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000000bU] = lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__12__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000000cU] = lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__13__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000000dU] = lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__14__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000000eU] = lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__15__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000000fU] = lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__16__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000010U] = lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__17__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000011U] = lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__18__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000012U] = lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__19__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000013U] = lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__20__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000014U] = lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__21__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000015U] = lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__22__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000016U] = lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__23__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000017U] = lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__24__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000018U] = lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__25__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000019U] = lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__26__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000001aU] = lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__27__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000001bU] = lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__28__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000001cU] = lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__29__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000001dU] = lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__30__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000001eU] = lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__31__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x0000001fU] = lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__32__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000020U] = lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__33__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000021U] = lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__34__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000022U] = lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__35__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000023U] = lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__36__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000024U] = lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__37__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000025U] = lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__38__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000026U] = lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__rounded)))))));
    lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__a 
        = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__full)
            ? 0x07ffffffU : (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__full)
                              ? 0x08000000U : (0x0fffffffU 
                                               & lowpass__DOT__g_sum__BRA__39__KET____DOT__u_add__DOT__full)));
    vlSelfRef.lowpass__DOT__acc[0x00000027U] = lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__a;
    lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__full 
        = (0x1fffffffU & (VL_EXTENDS_II(29,28, lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__a) 
                          + VL_EXTENDS_II(29,28, (VL_LTS_IQQ(48, 0x0000000007ffffffULL, vlSelfRef.lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__rounded)
                                                   ? 0x07ffffffU
                                                   : 
                                                  (VL_GTS_IQQ(48, 0x0000fffff8000000ULL, vlSelfRef.lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__rounded)
                                                    ? 0x08000000U
                                                    : 
                                                   (0x0fffffffU 
                                                    & (IData)(vlSelfRef.lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__rounded)))))));
    vlSelfRef.lowpass__DOT__acc[0x00000028U] = (VL_LTS_III(29, 0x07ffffffU, lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__full)
                                                 ? 0x07ffffffU
                                                 : 
                                                (VL_GTS_III(29, 0x18000000U, lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__full)
                                                  ? 0x08000000U
                                                  : 
                                                 (0x0fffffffU 
                                                  & lowpass__DOT__g_sum__BRA__40__KET____DOT__u_add__DOT__full)));
}

VL_ATTR_COLD void Vlowpass___024root___eval_stl(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_stl\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered[0U])) {
        Vlowpass___024root___stl_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD bool Vlowpass___024root___eval_phase__stl(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_phase__stl\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VstlExecute;
    // Body
    Vlowpass___024root___eval_triggers__stl(vlSelf);
    __VstlExecute = Vlowpass___024root___trigger_anySet__stl(vlSelfRef.__VstlTriggered);
    if (__VstlExecute) {
        Vlowpass___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

bool Vlowpass___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vlowpass___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(Vlowpass___024root___trigger_anySet__ico(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

bool Vlowpass___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

#ifdef VL_DEBUG
VL_ATTR_COLD void Vlowpass___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(Vlowpass___024root___trigger_anySet__act(triggers))))) {
        VL_DBG_MSGS("         No '" + tag + "' region triggers active\n");
    }
    if ((1U & (IData)(triggers[0U]))) {
        VL_DBG_MSGS("         '" + tag + "' region trigger index 0 is active: @(posedge clk)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vlowpass___024root___ctor_var_reset(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___ctor_var_reset\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    const uint64_t __VscopeHash = VL_MURMUR64_HASH(vlSelf->vlNamep);
    vlSelf->clk = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 16707436170211756652ull);
    vlSelf->resetn = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 8624841754543469506ull);
    vlSelf->din = VL_SCOPED_RAND_RESET_I(28, __VscopeHash, 15192908731043726583ull);
    vlSelf->din_strb = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 11647814735487848861ull);
    vlSelf->dout = VL_SCOPED_RAND_RESET_I(28, __VscopeHash, 11474705599699299244ull);
    vlSelf->dout_strb = VL_SCOPED_RAND_RESET_I(1, __VscopeHash, 6312377835021108597ull);
    for (int __Vi0 = 0; __Vi0 < 41; ++__Vi0) {
        vlSelf->lowpass__DOT__acc[__Vi0] = VL_SCOPED_RAND_RESET_I(28, __VscopeHash, 10286934463775251029ull);
    }
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__1__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__2__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__3__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__4__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__5__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__6__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__7__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__8__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__9__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__10__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__11__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__12__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__13__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__14__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__15__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__16__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__17__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__18__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__19__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__20__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__21__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__22__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__23__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__24__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__25__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__26__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__27__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__28__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__29__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__30__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__31__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__32__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__33__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__34__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__35__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__36__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__37__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__38__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__39__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_delay__BRA__40__KET____DOT__u_z__q = 0;
    vlSelf->lowpass__DOT____Vcellout__g_mul__BRA__0__KET____DOT__u_mul__dout = 0;
    vlSelf->lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 631005915215506706ull);
    vlSelf->lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 9747018572405712658ull);
    vlSelf->lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 6613872615536631817ull);
    vlSelf->lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 17149666042301333947ull);
    vlSelf->lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 4668229360153591532ull);
    vlSelf->lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 1020570552814320746ull);
    vlSelf->lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 6862871565961282533ull);
    vlSelf->lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 2738344503381298413ull);
    vlSelf->lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 6033278426250591682ull);
    vlSelf->lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 1028193944943920078ull);
    vlSelf->lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 14179146407590690021ull);
    vlSelf->lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 11629036751696642336ull);
    vlSelf->lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 15209378656144630490ull);
    vlSelf->lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 14274280599646406852ull);
    vlSelf->lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 13475169971623086224ull);
    vlSelf->lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 5682695433285653609ull);
    vlSelf->lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 1276933010213890125ull);
    vlSelf->lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 7784299486942176058ull);
    vlSelf->lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 2200226839364678832ull);
    vlSelf->lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 16346312504218128649ull);
    vlSelf->lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 12139368749113942440ull);
    vlSelf->lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 9120189789093164726ull);
    vlSelf->lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 16751609528691212453ull);
    vlSelf->lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 7715699443977757437ull);
    vlSelf->lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 3248575149196742904ull);
    vlSelf->lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 13563566334807289707ull);
    vlSelf->lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 797009851814282269ull);
    vlSelf->lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 6292449939893001153ull);
    vlSelf->lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 16412421033224503337ull);
    vlSelf->lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 5297444861195657985ull);
    vlSelf->lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 3860319457758144876ull);
    vlSelf->lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 17359075482299693204ull);
    vlSelf->lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 5568879270690433668ull);
    vlSelf->lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 14893738201408495003ull);
    vlSelf->lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 1209142240922208711ull);
    vlSelf->lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 10209032795411155382ull);
    vlSelf->lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 10428593531944080295ull);
    vlSelf->lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 11442555058013399418ull);
    vlSelf->lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 3525654544621251821ull);
    vlSelf->lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__rounded = VL_SCOPED_RAND_RESET_Q(48, __VscopeHash, 8796236970330407006ull);
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VstlTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VicoTriggered[__Vi0] = 0;
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VactTriggered[__Vi0] = 0;
    }
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = 0;
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->__VnbaTriggered[__Vi0] = 0;
    }
}
