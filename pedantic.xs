#define PERL_NO_GET_CONTEXT 1
#include "EXTERN.h"
#include "perl.h"

#ifdef WIN32
# include "XSUB.h"
#else /* not WIN32 */
# define PERL_CORE
# include "XSUB.h"
# undef PERL_CORE
#endif

#ifndef CvPROTO
# define CvPROTO(cv) SvPVX((SV*)(cv))
# define CvPROTOLEN(cv) SvCUR((SV*)(cv))
#endif /* !CvPROTO */

#define WP_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#define WP_HAS_RPEEP WP_HAS_PERL(5, 13, 5)
#if WP_HAS_RPEEP
#  define WP_PEEP PL_rpeepp
#else
#  define WP_PEEP PL_peepp
#endif

#ifndef PERL_ARGS_ASSERT_CK_WARNER
static void Perl_ck_warner(pTHX_ U32 err, const char* pat, ...);
 
#  ifdef vwarner
static
void
Perl_ck_warner(pTHX_ U32 err, const char* pat, ...)
{
  va_list args;
 
  PERL_UNUSED_ARG(err);
  if (ckWARN(err)) {
    va_list args;
    va_start(args, pat);
    vwarner(err, pat, &args);
    va_end(args);
  }
}
#  else
/* yes this replicates my_warner */
static
void
Perl_ck_warner(pTHX_ U32 err, const char* pat, ...)
{
  SV *sv;
  va_list args;
 
  PERL_UNUSED_ARG(err);
 
  va_start(args, pat);
  sv = vnewSVpvf(pat, &args);
  va_end(args);
  sv_2mortal(sv);
  warn("%s", SvPV_nolen(sv));
}
#  endif
#endif

#define MY_CXT_KEY "warnings::pedantic::_guts" XS_VERSION
 
typedef struct {
 HV* seen;
 HV* seen_where;
} my_cxt_t;
 
START_MY_CXT

static bool
THX_warn_for(pTHX_ U32 category)
#define warn_for(c) THX_warn_for(aTHX_ c)
{
    return !(PL_dowarn & G_WARN_ALL_OFF)
            && ( (PL_dowarn & G_WARN_ALL_ON)
                    || PL_curcop->cop_warnings == pWARN_ALL
                    || ckWARN(category) );
}
 
static U32 void_grep      = 0;
static U32 void_close     = 0;
static U32 void_print     = 0;
static U32 sort_prototype = 0;
static U32 ref_assignment = 0;
static U32 maybe_const    = 0;
static U32 once_lexical   = 0;

#define warnif4(x,m,a,b,c)  Perl_ck_warner(aTHX_ packWARN(x),m,a,b,c);
#define warnif(x,m)         warnif4(x, m, NULL, NULL, NULL)
#define warnif2(x,m,a)      warnif4(x, m, a, NULL, NULL)
#define warnif3(x,m,a,b)    warnif4(x, m, a, b, NULL)

STATIC GV*
THX_find_gv(pTHX_ OP* nextstate, SV* sv)
#define find_gv(n,sv) THX_find_gv(aTHX_ n, sv)  
{
                /* PL_curstash will msot likely be pointing to %main::,
                 * but we want the stash that this OP will be run under.
                 * This is important, because if they did
                 *    sort foo 1..10
                 * then all we'll get is a 'foo', which without this,
                 * we would end up looking in main::foo
                 */

    GV *gv;
    HV *curstash = PL_curstash;
    if (nextstate)  
        PL_curstash  = CopSTASH((COP*)nextstate);
    gv = gv_fetchsv(sv, 0, SVt_PVCV);
    PL_curstash  = curstash;
    return gv;
}

static peep_t prev_rpeepp = NULL;
STATIC void
my_rpeep(pTHX_ OP *o)
#define my_rpeep(o) my_rpeep(aTHX_ o)
{
    OP *orig_o = o;
    OP *nextstate = NULL;

    for(; o; o = o->op_next) {
        char *what = NULL;
        if ( o->op_opt ) {
            PL_curcop = &PL_compiling;
            prev_rpeepp(aTHX_ orig_o);
            return;
        }
        
        switch(o->op_type) {
            case OP_ENTERITER: {
                if ( !(o->op_private & OPpLVAL_INTRO) ) 
                    break;
                if ( o->op_private & OPpITER_DEF )
                    break;
                
                /* fallthrough */
            }
            case OP_PADSV: {
                dMY_CXT;
                HV *seen       = MY_CXT.seen;
                HV *seen_where = MY_CXT.seen_where;
                SV * sv = AvARRAY(PL_comppad_name)[o->op_targ];
            	SV * sva = PAD_BASE_SV(CvPADLIST(PL_compcv), o->op_targ);
            	
                if (!warn_for(once_lexical))
                    break;
            	
                if (SvFAKE(sv)) { /* Closed over var! */
                    SV** outpad;
                	CV *out = CvOUTSIDE(PL_compcv);
                    
                    if (!out)
                        croak("Can't happen?");
                    
                    sva = PAD_BASE_SV(CvPADLIST(out), PARENT_PAD_INDEX(sv)); 
                    
                    hv_store_ent(seen, newSViv(PTR2IV(sva)), newSViv(3), 0);
                }
                else if (o->op_private & OPpLVAL_INTRO) {
                    HE *he = hv_fetch_ent(seen, newSViv(PTR2IV(sva)), FALSE, 0);
            	    if (!he) {
            	        SV* keysv = newSViv(PTR2IV(sva));
            	        SV* store = newSVsv(sv);
            	        SV* where = newSVpvf("%s line %d", CopFILE(PL_curcop), CopLINE(PL_curcop));

            	        /* Jump through hoops in case this is optimized twice */
            	        SvUPGRADE(store, SVt_PVIV);
            	        SvIVX(store) = PTR2IV(o);
            	        
                        hv_store_ent(seen_where, keysv, where, 0);
                        hv_store_ent(seen, keysv, store, 0);
                    }
                    else if ( SvPOK(HeVAL(he)) ) {
                        SV *val = HeVAL(he);
                        if ( SvIVX(val) != PTR2IV(o) ) {
                            croak("How can this happen?");
                        }
                    }
                }
                else { /* Normal use */
                    hv_store_ent(seen, newSViv(PTR2IV(sva)), newSViv(2), 0);
                }
                break;
            }
            case OP_UNSTACK: {
                /* XXX TODO this stops an infinite loop with for(;;) {last} */
                o->op_opt = 1;
                break;
            }
            case OP_NULL:
                if ( o->op_targ == OP_LIST ) {
                    OP *p = cUNOPo->op_first;
                    
                    if (!p || !p->op_sibling)
                        break;
                    
                    p = p->op_sibling;
                    
                    while ( p ) {
                    
                        while ( p && p->op_type != OP_CONST )
                            p = p->op_sibling;
                        
                        if (!p)
                            break;
                    
                        if ( p->op_type == OP_CONST && p->op_private & OPpCONST_BARE )
                            {
                                SV * sv = cSVOPx_sv(p);
                                CV *cv;
                                GV *gv = find_gv(nextstate, sv);
                                if (!gv)
                                    break;
                                cv = GvCV(gv);
                                if (!cv)
                                    break;
                                if (!CvCONST(cv))
                                    break;
                                
                                warnif2(maybe_const, "\"%"SVf"\" used on the left hand side of the fat comma operator is also a constant in the current package", sv);
                                
                            }
                        p = p->op_sibling;
                    }
                }
                if (   o->op_targ != OP_NEXTSTATE
                    || o->op_targ != OP_DBSTATE )
                    break;
            case OP_DBSTATE:
            case OP_NEXTSTATE: {
                nextstate = o;
                PL_curcop = (COP*)(nextstate);
                break;
            }
            case OP_GREPWHILE: {
                U8 want = o->op_flags & OPf_WANT;
                if ((o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)) || o->op_opt)
                    break;
                
                if ( want != OPf_WANT_VOID )
                    break;
                
                warnif(void_grep,
                    "Unusual use of grep in void context");
                break;
            }
            case OP_CLOSEDIR:
                if (!what) {
                    what = "closedir";
                }
            case OP_CLOSE: {
                U8 want = o->op_flags & OPf_WANT;
                if (!what) {
                    what = "close";
                }
                if (o->op_opt || want != OPf_WANT_VOID)
                    break;
                
                warnif2(void_close,
                    "Unusual use of %s() in void context", what);
                
                break;
            }
            case OP_SAY:
                if (!what)
                    what = "say";
            case OP_PRTF:
                if (!what)
                    what = "printf";
            case OP_PRINT: {
                U8 want = o->op_flags & OPf_WANT;
                if (o->op_opt || want != OPf_WANT_VOID) {
                    what = NULL;
                    break;
                }

                if (!what)
                    what = "print";
                
                warnif2(void_print,
                    "Suspect use of %s() in void context", what);
                
                what = NULL;
                break;
            }
            case OP_SORT: {
                GV *gv;
                CV *cv;
                SV *sv;
                STRLEN protolen;
                const char * proto;
                OP * constop = NULL;
                OP * first = cUNOPx(o)->op_first->op_sibling;
                
                if (!warn_for(sort_prototype))
                    break;
                
                if ( first->op_type == OP_NULL ) {
                    constop = cUNOPx(first)->op_first;
                }
                
                if ( !constop || constop->op_type != OP_CONST )
                    break;
                
                sv = cSVOPx_sv(constop);
                gv = find_gv(nextstate, sv);
                
                if (!gv)
                    break;
                
                cv = GvCV(gv);
                
                if (!cv || !SvPOK(cv))
                    break;
                
                protolen = CvPROTOLEN(cv);
                proto = CvPROTO(cv);
                
                if (protolen == 2 && memEQ(proto, "$$", 2)) {
                    break;
                }
                else {
                    SV *const buffer = sv_newmortal();
                    gv = CvGV(cv) ? CvGV(cv) : gv;
                    gv_efullname3(buffer, gv, NULL);
                    warnif3(sort_prototype,
                        "Subroutine %"SVf"() used as first argument to sort, but has a %s prototype", buffer, proto);
                }
                break;
            }
            case OP_AASSIGN: {
                OP *right = cBINOPo->op_first;
                OP *left  = cBINOPo->op_last;
                char *del = NULL;
                
                if ( right->op_flags & OPf_PARENS )
                    break;
                
                if ( right->op_type == OP_NULL )
                    right = cUNOPx(right)->op_first;
                /* (), (1,...) */
                if (!right->op_sibling || right->op_sibling->op_sibling)
                    break;
                
                /* @a = (anything); is fine */
                if ( (right->op_flags & OPf_PARENS) || !right->op_sibling )
                    break;
                right = right->op_sibling;

                if ( right->op_flags & OPf_PARENS )
                    break;
                
                OP * targets = cUNOPx(left)->op_first;
                PERL_BITFIELD16 targ_one = targets->op_sibling->op_type;
                
                if ( targ_one == OP_RV2AV || targ_one == OP_PADAV ) {
                    if (right->op_type == OP_ANONLIST ) {
                        warnif(ref_assignment, "Assigning an arrayref to an array; did you mean (...) instead of [...]?");
                    }
                }
                                
                break;
            }
            case OP_HELEM: {
                OP * key = cBINOPo->op_last;
                SV * sv; CV *cv; GV *gv;
                
                if ( key->op_type != OP_CONST )
                    break;
                if ( !(key->op_private & OPpCONST_BARE) )
                    break;

                sv = cSVOPx_sv(key);
                
                gv = find_gv(nextstate, sv);
                
                if (!gv)
                    break;
                
                cv = GvCV(gv);
                
                if (!cv)
                    break;

                if (!CvCONST(cv))
                    break;

                
                warnif2(maybe_const, "Hash key \"%"SVf"\" is also a constant in the current package", sv);
            }
        }
    }
    
    PL_curcop = &PL_compiling;
    prev_rpeepp(aTHX_ orig_o);
}

MODULE = warnings::pedantic PACKAGE = warnings::pedantic

PROTOTYPES: DISABLE

BOOT:
{
    MY_CXT_INIT;
    MY_CXT.seen = newHV();
    MY_CXT.seen_where = newHV();
}

void
INIT()
CODE:
{
    dMY_CXT;
    HV *hv    = MY_CXT.seen;
    HV *where = MY_CXT.seen_where;

    /* Iterate through the pad variables we've seen and try to find out if
     * we have something used only once
     */
    HE *entry;
    (void)hv_iterinit(hv);
    while ((entry = hv_iternext(hv))) {
        SV * tmpstr = hv_iterval(hv,entry);
        if ( SvPOK(tmpstr) ) {
            SV* key = hv_iterkeysv(entry);
            HE* he = hv_fetch_ent(where, key, FALSE, 0);
            warn("Lexical variable %"SVf" used only once: possible typo at %"SVf, tmpstr, HeVAL(he));
        }
    }
    
    SvREFCNT_dec(hv);
    SvREFCNT_dec(where);
    MY_CXT.seen       = newHV();
    MY_CXT.seen_where = newHV();
}

void
start(SV *classname, U32 vg, U32 vc, U32 vp, U32 sop, U32 rea, U32 mc, U32 ol)
CODE:
    void_grep  = vg;
    void_close = vc;
    void_print = vp;
    sort_prototype = sop;
    ref_assignment = rea;
    maybe_const    = mc;
    once_lexical   = ol;
    if (!prev_rpeepp) {
        prev_rpeepp = WP_PEEP;
        WP_PEEP  = my_rpeep;
    }

void
done(SV *classname)
CODE:
    if ( WP_PEEP == my_rpeep ) {
        WP_PEEP = prev_rpeepp;
    }
    else {
        croak("WOAH THERE!! Something has gone HORRIBLY wrong!");
    }
