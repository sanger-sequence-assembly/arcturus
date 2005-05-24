import java.util.EventListener;

public interface ManagerEventListener extends EventListener {
  void managerUpdate(ManagerEvent e);
}
