import sys
import pscore


smtp_config = pscore.init(sys.argv[1])
pscore.main_sync()
pscore.de_init()
