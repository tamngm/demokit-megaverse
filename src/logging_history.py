import logging

# This is the "Settings" part. You only write this once.
logging.basicConfig(
    filename='history.log', 
    level=logging.DEBUG, 
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='w'
)
        
# This is the "messenger" you will export to other files
# ready to use logger objects such as debug, info, warn
logger = logging.getLogger("DemokitMegaverse")