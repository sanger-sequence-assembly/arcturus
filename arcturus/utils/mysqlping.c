/*  Last edited: Jul  9 09:10 2002 (adh) */
/*
#######################################################################
# This software has been created by Genome Research Limited (GRL).    # 
# GRL hereby grants permission to use, copy, modify and distribute    # 
# this software and its documentation for non-commercial purposes     # 
# without fee at the user's own risk on the basis set out below.      #
# GRL neither undertakes nor accepts any duty whether contractual or  # 
# otherwise in connection with the software, its use or the use of    # 
# any derivative, and makes no representations or warranties, express #
# or implied, concerning the software, its suitability, fitness for   #
# a particular purpose or non-infringement.                           #
# In no event shall the authors of the software or GRL be responsible # 
# or liable for any loss or damage whatsoever arising in any way      # 
# directly or indirectly out of the use of this software or its       # 
# derivatives, even if advised of the possibility of such damage.     #
# Our software can be freely distributed under the conditions set out # 
# above, and must contain this copyright notice.                      #
#######################################################################
#
# WHAT THIS PROGRAM DOES
# ----------------------
#
# mysqlping is a small Motif/X11 application which displays the status of
# one or more MySQL servers.
#
# It shows the string returned by the C API function mysql_stat. If an
# error occurs or if the server is unavailable, then a warning message is
# displayed in red.
#
# The display is updated every five seconds. This interval can be
# overridden by setting the environment variable MYSQLPING_TICKS.
#
# At each update, the program attempts to re-connect to any server which
# is unavailable.
#
# BUILDING THIS PROGRAM
# ---------------------
#
# Compile this program with -I flags for both MySQL and Motif include
# directories.
#
# Link with -L flags for the MySQL, Motif, Xt and X11 library directories
# and libraries in the order
#
#         -lXm -lXmu -lXt -lX11 -lmysqlclient -lm
#
# Note that -lXmu is only required if you have enabled Editres support
# with the -DINCLUDE_EDITRES_SUPPORT compiler flag.
#
# RUNNING THIS PROGRAM
# --------------------
#
#   mysqlclient host1:port1 [host2:port2 ...]
#
# Note that there is no default i.e. at least one host:port argument must
# be given. The program does not assume port 3306. You must specify this
# explicitly.
#
# Your servers must all be listening for connections on TCP ports.
#
# WHO WROTE THIS PROGRAM
# ----------------------
#
# Author:   David Harper
# Email:    adh@sanger.ac.uk
# WWW:      http://www.sanger.ac.uk/Users/adh/
#
*/

#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <Xm/Xm.h>
#include <Xm/Label.h>
#include <Xm/MainW.h>
#include <Xm/PushB.h>
#include <Xm/Form.h>

#ifdef INCLUDE_EDITRES_SUPPORT
#include <X11/Xmu/Editres.h>
#endif

static char *fallbacks[] = {
  "*form*background: wheat",
  "*hostname*background: tan",
  NULL
};

typedef struct _tagServerinfo {
  char *host;
  unsigned int port;
  Widget label;
  MYSQL mysql;
  time_t lastok;
  int status;
} ServerInfo;

static ServerInfo *servers;
int nServers;
unsigned long interval= 1000;

void quit(Widget w, XtPointer client_data, XtPointer call_data) {
  int j;

  for (j = 0; j < nServers; j++)
    if (servers[j].status == 0)
      mysql_close(&(servers[j].mysql));

  exit(0);
}

void SetTimer(Widget w, XtTimerCallbackProc proc, unsigned long tick) {
  XtAppContext app = XtWidgetToApplicationContext(w);
  XtPointer client_data = (XtPointer)w;

  XtAppAddTimeOut(app, tick, proc, client_data);
}

XmString serverping(ServerInfo *si) {
  MYSQL mysql;
  unsigned int client_flags = 0;
  unsigned int timeout = 1;
  char *msg;
  char buffer[256];
  XmString str;
  time_t now;

  now = time(NULL);

  if (si->status != 0) {
    mysql_init(&(si->mysql));

    if (!mysql_real_connect(&(si->mysql), si->host, "ping", NULL, NULL,
			    si->port, NULL, client_flags)) {
      si->status = -1;
      sprintf(buffer, "No connection for %d seconds; %s", (int)(now - si->lastok),
	      mysql_error(&(si->mysql)));
      return XmStringCreateLocalized(buffer);
    }
  }

  msg = mysql_stat(&(si->mysql));

  if (mysql_errno(&(si->mysql)) == 0) {
    str = XmStringCreateLocalized(msg);
    si->lastok = now;
    si->status = 0;
  } else {
    si->status = -1;
    sprintf(buffer, "Connection lost; %s", mysql_error(&(si->mysql)));
    return XmStringCreateLocalized(buffer);
  }

  return str;
}

void TimerCallback(XtPointer client_data, XtIntervalId *ID)
{
  Widget w = (Widget)client_data;
  int status;
  XmString str;
  int j;

  for (j = 0; j < nServers; j++) {
    str = serverping(&(servers[j]));

    XtVaSetValues(servers[j].label,
		  XmNlabelString, str,
		  NULL);

    if (servers[j].status == 0)
      XtVaSetValues(servers[j].label,
		    XtVaTypedArg, XmNforeground, XmRString, "black", 6,
		    NULL);
    else
      XtVaSetValues(servers[j].label,
		    XtVaTypedArg, XmNforeground, XmRString, "red", 4,
		    NULL);


    XmStringFree(str);
  }

  SetTimer(w, TimerCallback, interval);
}

ServerInfo *ParseServers(int argc, char **argv) {
  ServerInfo *si;
  char buffer[512];
  int j;
  char *host, *port;

  si = (ServerInfo *)calloc(argc, sizeof(ServerInfo));

  for (j = 0; j < argc; j++) {
    strcpy(buffer, argv[j]);
    port = strchr(buffer, ':');
    if (port) {
      *port = '\0';
      si[j].port = atoi(++port);
    } else
      si[j].port = 3306;

    si[j].host = strdup(buffer);
  }

  return si;
}

int main(int argc, char **argv) {
  Widget toplevel, main_w, form, menu, label, lastlabel;
  Widget btnQuit;
  int options = 0;
  XtAppContext app;
  XmString str;
  int j, k;
  char *progname = argv[0];
  char buffer[512];
  char *cp;
  unsigned long zero = 0L;
  time_t now;

  now = time(NULL);

  cp = getenv("MYSQLPING_TICKS");
  if (cp)
    interval = 1000 * atoi(cp);
  else
    interval = 5000;

  servers = ParseServers(argc-1, argv+1);

  nServers = argc - 1;

  if (nServers < 1) {
    fprintf(stderr, "Usage: %s host:port ...\n", progname);
    return 1;
  }

  XtSetLanguageProc(NULL, NULL, NULL);

  toplevel = XtAppInitialize(&app, "MySQL_Monitor", NULL, 0, &argc, argv, fallbacks, NULL, 0);

  main_w = XtVaCreateManagedWidget("main_window",
				   xmMainWindowWidgetClass, toplevel,
				   XmNshowSeparator, True,
				   NULL);

  form = XtVaCreateManagedWidget("form",
				 xmFormWidgetClass, main_w,
				 XmNtopAttachment, XmATTACH_FORM,
				 XmNleftAttachment, XmATTACH_FORM,
				 XmNrightAttachment, XmATTACH_FORM,
				 XmNbottomAttachment, XmATTACH_FORM,
				 NULL);

  for (j = 0; j < nServers; j++) {
    sprintf(buffer, "%s:%u", servers[j].host, servers[j].port);

    servers[j].lastok = now;
    servers[j].status = -1;

    str = XmStringCreateLocalized(buffer);

    label = XtVaCreateManagedWidget("hostname",
				    xmLabelWidgetClass, form,
				    XmNlabelString, str,
				    XmNleftAttachment, XmATTACH_FORM,
				    XmNrecomputeSize, False,
				    XmNwidth, 100,
				    XmNalignment, XmALIGNMENT_BEGINNING,
				    XmNmarginLeft, 3,
				    XmNmarginRight, 5,
				    XmNmarginBottom, 3,
				    NULL);

    XmStringFree(str);

    if (j == 0)
      XtVaSetValues(label,
		    XmNtopAttachment, XmATTACH_FORM,
		    XmNtopOffset, 3,
		    NULL);
    else
      XtVaSetValues(label,
		    XmNtopAttachment, XmATTACH_WIDGET,
		    XmNtopWidget, lastlabel,
		    XmNtopOffset, 3,
		    NULL);

    lastlabel = label;

    sprintf(buffer, "%s:%u", servers[j].host, servers[j].port);

    servers[j].label = XtVaCreateManagedWidget(buffer,
					       xmLabelWidgetClass, form,
					       XmNalignment, XmALIGNMENT_BEGINNING,
					       XmNleftAttachment, XmATTACH_WIDGET,
					       XmNleftWidget, label,
					       XmNleftOffset, 5,
					       XmNtopAttachment, XmATTACH_OPPOSITE_WIDGET,
					       XmNtopWidget, label,
					       XmNbottomAttachment, XmATTACH_OPPOSITE_WIDGET,
					       XmNbottomWidget, label,
					       XmNrightAttachment, XmATTACH_FORM,
					       XmNrightOffset, 3,
					       XmNwidth, 840,
					       NULL);
  }


  SetTimer(form, TimerCallback, zero);

  XtVaSetValues(main_w,
		XmNworkWindow, form,
		NULL);

#ifdef INCLUDE_EDITRES_SUPPORT
  XtAddEventHandler(toplevel,
		    (EventMask) 0,
		    True,
		    (XtEventHandler) _XEditResCheckMessages,
		    NULL);
#endif

  XtRealizeWidget(toplevel);

  XtAppMainLoop(app);

  return 0;
}


