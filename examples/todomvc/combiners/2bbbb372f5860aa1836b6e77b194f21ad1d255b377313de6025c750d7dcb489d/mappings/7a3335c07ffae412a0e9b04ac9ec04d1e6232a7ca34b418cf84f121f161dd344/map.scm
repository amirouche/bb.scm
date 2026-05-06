((doc . "todos: HTTP handler for the TodoMVC app.\nstate: box holding (cons next-id todos-list)\nPOST /?action=toggle&id=N  — toggle completed flag\nPOST /?action=delete&id=N  — remove todo\nPOST /?action=clear         — remove all completed\nPOST /                      — add todo (body: t=TEXT)\nGET  /                      — render page")
 (function . "2bbbb372f5860aa1836b6e77b194f21ad1d255b377313de6025c750d7dcb489d")
 (language . "en")
 (mapping . ((0 . "todos") (1 . "state") (2 . "req"))))