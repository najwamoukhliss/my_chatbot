import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  var messages = [];
  String? attachedImageBase64;
  bool isLoading = false;
  TextEditingController messageController = TextEditingController();
  ScrollController scrollController = ScrollController();

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void showFullImage(String imageProvider, {bool isBase64 = false}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          color: Colors.black,
          child: PhotoView(
            imageProvider: isBase64
                ? MemoryImage(base64Decode(imageProvider))
                : NetworkImage(imageProvider) as ImageProvider,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SBR ChatBot", style: TextStyle(color: Theme.of(context).indicatorColor)),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/');
            },
            icon: Icon(Icons.logout),
            color: Theme.of(context).indicatorColor,
          )
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isUser = msg['role'] == 'user';
              final hasImage = msg.containsKey('image');
              final hasImageUrl = msg.containsKey('imageUrl');

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: CircleAvatar(child: Text("🤖")),
                    ),
                  Flexible(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.lightGreen : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasImage)
                            GestureDetector(
                              onTap: () => showFullImage(msg['image'], isBase64: true),
                              child: Image.memory(
                                base64Decode(msg['image']),
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (hasImageUrl)
                            GestureDetector(
                              onTap: () => showFullImage(msg['imageUrl']),
                              child: Image.network(
                                msg['imageUrl'],
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          SizedBox(height: 8),
                          Text(msg['content'] ?? "", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  if (isUser)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(child: Text("👤")),
                    ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            if (attachedImageBase64 != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(attachedImageBase64!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          attachedImageBase64 = null;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: "Ask anything",
                    suffixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        width: 1,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.image),
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedImage = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedImage != null) {
                    final bytes = await pickedImage.readAsBytes();
                    setState(() {
                      attachedImageBase64 = base64Encode(bytes);
                    });
                  }
                },
              ),
              isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () async {
                        String question = messageController.text.trim();
                        if (question.isEmpty && attachedImageBase64 == null) return;

                        final openAiKey = dotenv.env['OPENAI_API_KEY'];
                        final headers = {
                          "Content-Type": "application/json",
                          "Authorization": "Bearer $openAiKey"
                        };

                        setState(() {
                          isLoading = true;
                        });

                        final lower = question.toLowerCase();
                        final isImagePrompt = lower.startsWith("generate") ||
                            lower.startsWith("create") ||
                            lower.contains("generate an image") ||
                            lower.contains("create an image");

                        if (isImagePrompt) {
                          messages.add({"role": "user", "content": question});
                          try {
                            final resp = await http.post(
                              Uri.parse("https://api.openai.com/v1/images/generations"),
                              headers: headers,
                              body: jsonEncode({
                                "prompt": question,
                                "n": 1,
                                "size": "512x512"
                              }),
                            );

                            final imageUrl = jsonDecode(resp.body)['data'][0]['url'];
                            setState(() {
                              messages.add({
                                "role": "assistant",
                                "content": "Here is the image you requested:",
                                "imageUrl": imageUrl
                              });
                            });
                          } catch (e) {
                            print("DALL·E Error: $e");
                          }
                        } else if (attachedImageBase64 != null) {
                          messages.add({
                            "role": "user",
                            "content": question.isEmpty ? "[Image]" : question,
                            "image": attachedImageBase64
                          });

                          var body = jsonEncode({
                            "model": "gpt-4o",
                            "messages": [
                              {
                                "role": "user",
                                "content": [
                                  {
                                    "type": "text",
                                    "text": question.isEmpty ? "Describe this image" : question
                                  },
                                  {
                                    "type": "image_url",
                                    "image_url": {
                                      "url": "data:image/jpeg;base64,$attachedImageBase64"
                                    }
                                  }
                                ]
                              }
                            ]
                          });

                          try {
                            final resp = await http.post(
                              Uri.parse("https://api.openai.com/v1/chat/completions"),
                              headers: headers,
                              body: body,
                            );
                            final answer = jsonDecode(resp.body)['choices'][0]['message']['content'];
                            setState(() {
                              messages.add({"role": "assistant", "content": answer});
                              attachedImageBase64 = null;
                            });
                          } catch (err) {
                            print("Image+Text error: $err");
                          }
                        } else {
                          messages.add({"role": "user", "content": question});

                          var body = jsonEncode({
                            "model": "gpt-4o",
                            "messages": messages.map((msg) => {
                                  "role": msg['role'],
                                  "content": msg['content']
                                }).toList()
                          });

                          try {
                            final resp = await http.post(
                              Uri.parse("https://api.openai.com/v1/chat/completions"),
                              headers: headers,
                              body: body,
                            );
                            final answer = jsonDecode(resp.body)['choices'][0]['message']['content'];
                            setState(() {
                              messages.add({"role": "assistant", "content": answer});
                            });
                          } catch (err) {
                            print("Text error: $err");
                          }
                        }

                        messageController.clear();
                        isLoading = false;
                        scrollToBottom();
                      },
                    )
            ])
          ]),
        )
      ]),
    );
  }
}