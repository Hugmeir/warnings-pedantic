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
THX_warn_for(pTHX_ OP* o, U32 category)
#define warn_for(o,c) THX_warn_for(aTHX_ o,c)
{
    bool do_warn = FALSE;
    
    /* PL_curcop->cop_warnings might be NULL/empty, in which case
     * we need to find the nearest OP_NEXTSTATE and check if the warning
     * is on. ...I think.
     */
    if (!PL_curcop->cop_warnings) {
        OP *next = NULL;
        for ( next = o->op_next; next; next = next->op_next ) {
            switch (next->op_type) {
                case OP_NULL:
                    if (   o->op_targ != OP_NEXTSTATE
                        || o->op_targ != OP_DBSTATE )
                        break;
                case OP_DBSTATE:
                case OP_NEXTSTATE:
                    PL_curcop = (COP*)(next);
                    break;
            }
        }
    
    }

    return !(PL_dowarn & G_WARN_ALL_OFF)
            && ( (PL_dowarn & G_WARN_ALL_ON)
                    || ckWARN(WARN_ALL)
                    || ckWARN(category) );
}
 
static unsigned long warn_category = 0;

static peep_t prev_rpeepp = NULL;
STATIC void
my_rpeep(pTHX_ OP *o)
{
    OP *orig_o = o;
    for(; o; o = o->op_next) {
        switch(o->op_type) {
            case OP_GREPWHILE: {
                U8 want = o->op_flags & OPf_WANT;
                if ((o->op_private & (OPpLVAL_INTRO|OPpOUR_INTRO)) || o->op_opt)
                    break;
                
                if ( want != OPf_WANT_VOID )
                    break;
                
                if (warn_for(o, warn_category)) {
                    warn("Unusual use of grep in void context");
                }
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
    warn_category = category;
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
