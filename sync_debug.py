import sys
import ps_core


smtp_config = ps_core.init(sys.argv[1])
ps_core.main_sync()
ps_core.de_init()
