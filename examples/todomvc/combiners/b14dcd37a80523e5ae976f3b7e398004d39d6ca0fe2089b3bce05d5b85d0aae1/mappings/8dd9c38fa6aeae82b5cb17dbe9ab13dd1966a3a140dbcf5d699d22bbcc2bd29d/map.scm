((doc . "todos: HTTP handler for the TodoMVC app.\nstate: box holding (cons next-id todos-list)\nPOST /?action=toggle&id=N  — toggle completed flag\nPOST /?action=delete&id=N  — remove todo\nPOST /?action=clear         — remove all completed\nPOST /                      — add todo (body: t=TEXT)\nGET  /                      — render page")
 (function . "b14dcd37a80523e5ae976f3b7e398004d39d6ca0fe2089b3bce05d5b85d0aae1")
 (language . "en")
 (mapping . ((0 . "todos") (1 . "state") (2 . "req"))))