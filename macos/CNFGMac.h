#ifndef CNPING_CNFG_MAC_H
#define CNPING_CNFG_MAC_H

// When launched from a Finder app bundle without arguments, ask for a target.
int MacIsAppBundle(void);
char *MacPromptForHost(void);

#endif
