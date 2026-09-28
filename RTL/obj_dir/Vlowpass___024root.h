// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vlowpass.h for the primary calling header

#ifndef VERILATED_VLOWPASS___024ROOT_H_
#define VERILATED_VLOWPASS___024ROOT_H_  // guard

#include "verilated.h"


class Vlowpass__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vlowpass___024root final {
  public:

    // DESIGN SPECIFIC STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        VL_IN8(clk,0,0);
        VL_IN8(resetn,0,0);
        VL_IN8(din_strb,0,0);
        VL_OUT8(dout_strb,0,0);
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __VicoFirstIteration;
        CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
        VL_IN(din,27,0);
        VL_OUT(dout,27,0);
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__1__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__2__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__3__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__4__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__5__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__6__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__7__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__8__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__9__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__10__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__11__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__12__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__13__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__14__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__15__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__16__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__17__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__18__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__19__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__20__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__21__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__22__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__23__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__24__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__25__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__26__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__27__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__28__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__29__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__30__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__31__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__32__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__33__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__34__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__35__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__36__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__37__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__38__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__39__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_delay__BRA__40__KET____DOT__u_z__q;
        IData/*27:0*/ lowpass__DOT____Vcellout__g_mul__BRA__0__KET____DOT__u_mul__dout;
        IData/*31:0*/ __VactIterCount;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__1__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__2__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__3__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__4__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__5__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__6__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__7__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__8__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__9__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__10__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__11__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__12__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__13__KET____DOT__u_mul__DOT__rounded;
    };
    struct {
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__14__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__15__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__16__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__17__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__18__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__19__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__20__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__21__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__22__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__23__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__24__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__25__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__26__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__27__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__28__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__29__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__30__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__31__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__32__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__33__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__34__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__35__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__36__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__37__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__38__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__39__KET____DOT__u_mul__DOT__rounded;
        QData/*47:0*/ lowpass__DOT__g_mul__BRA__40__KET____DOT__u_mul__DOT__rounded;
        VlUnpacked<IData/*27:0*/, 41> lowpass__DOT__acc;
        VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
        VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    };

    // INTERNAL VARIABLES
    Vlowpass__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vlowpass___024root(Vlowpass__Syms* symsp, const char* namep);
    ~Vlowpass___024root();
    VL_UNCOPYABLE(Vlowpass___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
