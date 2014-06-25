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

static bool
THX_warn_for(pTHX_ OP* o, OP* nextstate, U32 category, U32 category2)
#define warn_for(o,n,c,c2) THX_warn_for(aTHX_ o,n,c,c2)
{
    bool do_warn = FALSE;
    
    /* PL_curcop->cop_warnings might be NULL/empty, in which case
     * we need to find the nearest OP_NEXTSTATE and check if the warning
     * is on. ...I think.
     */
    if (!PL_curcop->cop_warnings) {
        PL_curcop = (COP*)(nextstate);
    }

    return !(PL_dowarn & G_WARN_ALL_OFF)
            && ( (PL_dowarn & G_WARN_ALL_ON)
                    || PL_curcop->cop_warnings == pWARN_ALL
                    || (ckWARN(category) && (category2 ? ckWARN(category2) : 1) ) );
}
 
static U32 pedantic      = 0;
static U32 void_grep     = 0;
static U32 void_close    = 0;
static U32 void_print    = 0;

static peep_t prev_rpeepp = NULL;
STATIC void
my_rpeep(pTHX_ OP *o)
{
    OP *orig_o = o;
    OP *nextstate = NULL;
    for(; o; o = o->op_next) {
        char *what = NULL;
        switch(o->op_type) {
            case OP_NULL:
                if (   o->op_targ != OP_NEXTSTATE
                    || o->op_targ != OP_DBSTATE )
                    break;
            case OP_DBSTATE:
            case OP_NEXTSTATE: {
                nextstate = o;
                break;
            }
            case OP_GREPWHILE: {
                U8 want = o->op_flags & OPf_WANT;
                if ((o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)) || o->op_opt)
                    break;
                
                if ( want != OPf_WANT_VOID )
                    break;
                
                if (warn_for(o, nextstate, pedantic, void_grep)) {
                    warn("Unusual use of grep in void context");
                }
                break;
            }
            case OP_CLOSE: {
                U8 want = o->op_flags & OPf_WANT;
                if (o->op_opt || want != OPf_WANT_VOID)
                    break;
                
                if (warn_for(o, nextstate, pedantic, void_close)) {
                    warn("Unusual use of close() in void context");
                }
                
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
                
                if (warn_for(o, nextstate, pedantic, void_print)) {
                    warn("Suspect use of %s() in void context", what);
                }
                
                what = NULL;
                break;
            }
        }
    }
    prev_rpeepp(aTHX_ orig_o);
}
 
MODULE = warnings::pedantic PACKAGE = warnings::pedantic

PROTOTYPES: DISABLE

void
start(SV *classname, U32 category)
CODE:
    pedantic   = category;
    void_grep  = pedantic + 1;
    void_close = pedantic + 2;
    void_print = pedantic + 3;
    if (!prev_rpeepp) {
        prev_rpeepp = PL_rpeepp;
        PL_rpeepp = my_rpeep;
    }

void
done(SV *classname)
CODE:
    if ( PL_rpeepp == my_rpeep ) {
        PL_rpeepp = prev_rpeepp;
    }
    else {
        croak("WOAH THERE!! Something has gone HORRIBLY wrong!");
    }
