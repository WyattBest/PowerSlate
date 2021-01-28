import sys
import pscore


smtp_config = pscore.init_config(sys.argv[1])
pscore.main_sync()
pscore.de_init()
