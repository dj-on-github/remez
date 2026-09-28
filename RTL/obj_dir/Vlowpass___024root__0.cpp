// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vlowpass.h for the primary calling header

#include "Vlowpass__pch.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vlowpass___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

void Vlowpass___024root___eval_triggers__ico(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_triggers__ico\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered
                                      [0U]) | (IData)((IData)(vlSelfRef.__VicoFirstIteration)));
    vlSelfRef.__VicoFirstIteration = 0U;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vlowpass___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
}

bool Vlowpass___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___trigger_anySet__ico\n"); );
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

void Vlowpass___024root___ico_sequent__TOP__0(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___ico_sequent__TOP__0\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__prod;
    lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__prod = 0;
    QData/*47:0*/ lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded;
    lowpass__DOT__g_mul__BRA__0__KET____DOT__u_mul__DOT__rounded = 0;
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

void Vlowpass___024root___eval_ico(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_ico\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VicoTriggered[0U])) {
        Vlowpass___024root___ico_sequent__TOP__0(vlSelf);
    }
}

bool Vlowpass___024root___eval_phase__ico(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_phase__ico\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VicoExecute;
    // Body
    Vlowpass___024root___eval_triggers__ico(vlSelf);
    __VicoExecute = Vlowpass___024root___trigger_anySet__ico(vlSelfRef.__VicoTriggered);
    if (__VicoExecute) {
        Vlowpass___024root___eval_ico(vlSelf);
    }
    return (__VicoExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vlowpass___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

void Vlowpass___024root___eval_triggers__act(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_triggers__act\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                    ((IData)(vlSelfRef.clk) 
                                                     & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__clk__0)))));
    vlSelfRef.__Vtrigprevexpr___TOP__clk__0 = vlSelfRef.clk;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vlowpass___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
}

bool Vlowpass___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___trigger_anySet__act\n"); );
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

void Vlowpass___024root___nba_sequent__TOP__0(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___nba_sequent__TOP__0\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
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
    vlSelfRef.dout_strb = ((IData)(vlSelfRef.resetn) 
                           && (IData)(vlSelfRef.din_strb));
    if (vlSelfRef.resetn) {
        if (vlSelfRef.din_strb) {
            vlSelfRef.dout = vlSelfRef.lowpass__DOT__acc
                [0x28U];
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__40__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__39__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__39__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__38__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__38__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__37__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__37__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__36__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__36__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__35__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__35__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__34__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__34__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__33__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__33__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__32__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__32__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__31__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__31__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__30__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__30__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__29__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__29__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__28__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__28__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__27__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__27__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__26__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__26__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__25__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__25__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__24__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__24__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__23__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__23__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__22__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__22__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__21__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__21__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__20__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__20__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__19__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__19__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__18__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__18__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__17__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__17__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__16__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__16__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__15__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__15__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__14__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__14__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__13__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__13__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__12__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__12__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__11__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__11__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__10__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__10__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__9__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__9__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__8__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__8__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__7__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__7__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__6__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__6__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__5__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__5__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__4__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__4__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__3__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__3__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__2__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__2__KET____DOT__u_z__q 
                = vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__1__KET____DOT__u_z__q;
            vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__1__KET____DOT__u_z__q 
                = vlSelfRef.din;
        }
    } else {
        vlSelfRef.dout = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__40__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__39__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__38__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__37__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__36__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__35__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__34__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__33__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__32__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__31__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__30__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__29__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__28__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__27__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__26__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__25__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__24__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__23__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__22__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__21__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__20__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__19__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__18__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__17__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__16__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__15__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__14__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__13__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__12__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__11__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__10__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__9__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__8__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__7__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__6__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__5__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__4__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__3__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__2__KET____DOT__u_z__q = 0U;
        vlSelfRef.lowpass__DOT____Vcellout__g_delay__BRA__1__KET____DOT__u_z__q = 0U;
    }
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

void Vlowpass___024root___eval_nba(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_nba\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
        Vlowpass___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vlowpass___024root___trigger_orInto__act(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___trigger_orInto__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vlowpass___024root___eval_phase__act(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_phase__act\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vlowpass___024root___eval_triggers__act(vlSelf);
    Vlowpass___024root___trigger_orInto__act(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    return (0U);
}

void Vlowpass___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

bool Vlowpass___024root___eval_phase__nba(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_phase__nba\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vlowpass___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        Vlowpass___024root___eval_nba(vlSelf);
        Vlowpass___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

void Vlowpass___024root___eval(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    IData/*31:0*/ __VicoIterCount;
    IData/*31:0*/ __VnbaIterCount;
    // Body
    __VicoIterCount = 0U;
    vlSelfRef.__VicoFirstIteration = 1U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VicoIterCount)))) {
#ifdef VL_DEBUG
            Vlowpass___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
#endif
            VL_FATAL_MT("lowpass.sv", 147, "", "Input combinational region did not converge after 100 tries");
        }
        __VicoIterCount = ((IData)(1U) + __VicoIterCount);
    } while (Vlowpass___024root___eval_phase__ico(vlSelf));
    __VnbaIterCount = 0U;
    do {
        if (VL_UNLIKELY(((0x00000064U < __VnbaIterCount)))) {
#ifdef VL_DEBUG
            Vlowpass___024root___dump_triggers__act(vlSelfRef.__VnbaTriggered, "nba"s);
#endif
            VL_FATAL_MT("lowpass.sv", 147, "", "NBA region did not converge after 100 tries");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        vlSelfRef.__VactIterCount = 0U;
        do {
            if (VL_UNLIKELY(((0x00000064U < vlSelfRef.__VactIterCount)))) {
#ifdef VL_DEBUG
                Vlowpass___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
#endif
                VL_FATAL_MT("lowpass.sv", 147, "", "Active region did not converge after 100 tries");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
        } while (Vlowpass___024root___eval_phase__act(vlSelf));
    } while (Vlowpass___024root___eval_phase__nba(vlSelf));
}

#ifdef VL_DEBUG
void Vlowpass___024root___eval_debug_assertions(Vlowpass___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vlowpass___024root___eval_debug_assertions\n"); );
    Vlowpass__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if (VL_UNLIKELY(((vlSelfRef.clk & 0xfeU)))) {
        Verilated::overWidthError("clk");
    }
    if (VL_UNLIKELY(((vlSelfRef.resetn & 0xfeU)))) {
        Verilated::overWidthError("resetn");
    }
    if (VL_UNLIKELY(((vlSelfRef.din & 0xf0000000U)))) {
        Verilated::overWidthError("din");
    }
    if (VL_UNLIKELY(((vlSelfRef.din_strb & 0xfeU)))) {
        Verilated::overWidthError("din_strb");
    }
}
#endif  // VL_DEBUG
