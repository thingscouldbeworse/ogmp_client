FontSetup main_font("arial", 30 , vec4(0,0,0,0.75), false);
FontSetup error_font("arial", 40 , vec4(0.85,0,0,0.75), true);
FontSetup client_connect_font("arial", 50 , vec4(1,1,1,0.75), true);
FontSetup client_connect_font_small("arial", 30 , vec4(1,1,1,0.75), true);
IMMouseOverPulseColor mouseover_fontcolor(vec4(1), vec4(1), 5.0f);
IMPulseAlpha pulse(1.0f, 0.0f, 2.0f);
string connected_icon = "UI/ClientConnect/images/connected.png";
string disconnected_icon = "UI/ClientConnect/images/disconnected.png";
string white_background = "Textures/ui/menus/main/white_square.png";

string turner = "Data/Characters/ogmp/turner.xml";

array<string> adjectives = {"Little", "Old", "Bad", "Brave", "Handsome", "Quaint", "Prickly", "Nervous", "Jolly", "Gigantic", "Itchy", "Thoughtless", "Crooked", "Hissing", "Slow", "Flaky", "Damaged"};
array<string> nouns = {"Cat", "Walnut", "Bird", "Cookie", "Aardvark", "Boy", "Dame", "Kitty", "Person", "Cow", "Dragon", "Investor", "Cook", "Frenchman", "Priest", "Tiger", "Zebra", "Raven", "David"};

//Message types 
uint8 SignOn = 0;
uint8 Message = 1;
uint8 TimeOut = 2;
uint8 SpawnCharacter = 3;
uint8 RemoveCharacter = 4;
uint8 UpdateGame = 5;
uint8 UpdateSelf = 6;
uint8 SavePosition = 7;
uint8 LoadPosition = 8;
uint8 UpdateCharacter = 9;
uint8 Error = 10;
uint8 ServerInfo = 11;

uint retriever_socket = SOCKET_ID_INVALID;
uint main_socket = SOCKET_ID_INVALID;

ServerRetriever server_retriever;

array<ServerConnectionInfo@> server_list = {	ServerConnectionInfo("127.0.0.1", 2000),
												ServerConnectionInfo("127.0.0.1", 80),
												ServerConnectionInfo("127.0.0.1", 1337)};
												/*ServerConnectionInfo("52.56.230.41", 80)};*/

class ServerConnectionInfo{
	string server_name;
	int nr_players;
	string address;
	int port;
	bool valid = false;
	double latency;
	ServerConnectionInfo(string address_, int port_){
		address = address_;
		port = port_;
	}
}

class ServerRetriever{
	bool checking_servers = false;
	int max_connect_tries = 5;
	int connect_tries = 0;
	float connect_try_interval = 0.1f;
	float timer = 0.0f;
	int server_index = 0;
	uint64 start_time;
	array<ServerConnectionInfo@> online_servers;
	bool getting_server_info = false;
	void Update(){
		if(checking_servers && !getting_server_info){
			if(server_index >= int(server_list.size())){
				checking_servers = false;
				return;
			}
			timer += time_step;
			//Every interval check for a connection
			if(timer > connect_try_interval){
				timer = 0.0f;
				if( retriever_socket == SOCKET_ID_INVALID ) {
		            Log( info, "Trying to connect" );
					start_time = GetPerformanceCounter();
					retriever_socket = CreateSocketTCP(server_list[server_index].address, server_list[server_index].port);
		            if( retriever_socket != SOCKET_ID_INVALID ) {
						Log( info, "Connected " + server_list[server_index].address + "!!!!");
						server_list[server_index].latency = (GetPerformanceCounter() - start_time) * 1000.0 / GetPerformanceFrequency();
						Print("Latency " + server_list[server_index].latency + " miliseconds\n");
						
						online_servers.insertLast(server_list[server_index]);
						GetNextServer();
		            } else {
		                Log( warning, "Unable to connect");
		            }
		        }
				if( !IsValidSocketTCP(retriever_socket) ){
					Log(info, "invalid");
					retriever_socket = SOCKET_ID_INVALID;
				}else{
					Log(info, "valid");
					array<uint8> info_message = {ServerInfo};
					SocketTCPSend(retriever_socket,info_message);
					getting_server_info = true;
				}
				connect_tries++;
				if(connect_tries == max_connect_tries){
					connect_tries = 0;
					GetNextServer();
				}
			}
		}
	}
	void SetServerInfo(string server_name_, int nr_players_){
		online_servers[online_servers.size() - 1].server_name = server_name_;
		online_servers[online_servers.size() - 1].nr_players = nr_players_;
		getting_server_info = false;
		retriever_socket = SOCKET_ID_INVALID;
	}
	void GetNextServer(){
		server_index++;
		if(server_index >= int(server_list.size())){
			checking_servers = false;
		}
	}
}

class RemotePlayer{
	int object_id;
	string username;
	string team;
	RemotePlayer(string username_, string team_, int object_id_){
		username = username_;
		team = team_;
		object_id = object_id_;
	}
}
class Inputfield {
	bool active = false;
	bool pressed_return = false;
	int initial_sequence_id;
	IMText@ input_field;
	IMDivider@ parent;
	string query = "";
	int current_index = 0;
	int cursor_offset = 0;
	float long_press_input_timer = 0.0f;
	float long_press_timer = 0.0f;
	float long_press_threshold = 0.5f;
	float long_press_interval = 0.1f;
	uint max_query_length = 20;
	Inputfield(){
		
	}
	void ResetSearch(){
		query = "";
		active = false;
		pressed_return = false;
	}
	void Activate(){
		if(active){return;}
		
		//Freeze the player so it doesn't walk around.
		MovementObject@ player = ReadCharacter(player_id);
		player.velocity = vec3(0);
		player.Execute("SetState(_ground_state);");
		
		query = "";
		active = true;
		array<KeyboardPress> inputs = GetRawKeyboardInputs();
		if(inputs.size() > 0){
			initial_sequence_id = inputs[inputs.size()-1].s_id;
		}else{
			initial_sequence_id = -1;
		}
		parent.clear();
		/*parent.clearLeftMouseClickBehaviors();*/
		IMText new_input_field("", client_connect_font);
		parent.append(new_input_field);
		@input_field = @new_input_field;
		IMText cursor("_", client_connect_font);
		cursor.addUpdateBehavior(pulse, "");
		cursor.setZOrdering(4);
		parent.append(cursor);
	}
	void Deactivate(){
		active = false;
		parent.clear();
		IMText new_input_field(query, client_connect_font);
		parent.append(new_input_field);
		@input_field = @new_input_field;
	}
	void SetInputField(IMText@ _input_field, IMDivider@ _parent){
		@input_field = @_input_field;
		@parent = @_parent;
	}
	void Update(){
		if(active){
			if(GetInputPressed(0, "left")){
				if((cursor_offset) < int(query.length())){
					cursor_offset++;
					SetCurrentSearchQuery();
				}
			}
			else if(GetInputPressed(0, "right")){
				if(cursor_offset > 0){
					cursor_offset--;
					SetCurrentSearchQuery();
				}
			}
			if(long_press_timer > long_press_threshold){
				if(GetInputDown(0, "backspace")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						//Check if there are enough chars to delete the last one.
						if(query.length() - cursor_offset > 0){
							uint new_length = query.length() - 1;
							if(new_length >= 0 && new_length <= max_query_length){
								query.erase(query.length() - cursor_offset - 1, 1);
								SetCurrentSearchQuery();
								return;
							}
						}else{
							return;
						}
					}
				}else if(GetInputDown(0, "delete")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						//Check if there are enough chars to delete the next one.
						if(cursor_offset > 0){
							query.erase(query.length() - cursor_offset, 1);
							cursor_offset--;
							SetCurrentSearchQuery();
						}
						return;
					}
				}else if(GetInputDown(0, "left")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						if((cursor_offset) < int(query.length())){
							cursor_offset++;
							SetCurrentSearchQuery();
						}
					}
					return;
				}else if(GetInputDown(0, "right")){
					long_press_input_timer += time_step;
					if(long_press_input_timer > long_press_interval){
						long_press_input_timer = 0.0f;
						if(cursor_offset > 0){
							cursor_offset--;
							imGUI.receiveMessage( IMMessage("refresh_menu_by_id") );
						}
					}
					return;
				}else{
					long_press_input_timer = 0.0f;
				}
				if(!GetInputDown(0, "delete") && !GetInputDown(0, "backspace") && !GetInputDown(0, "left") && !GetInputDown(0, "right")){
					long_press_timer = 0.0f;
				}
			}else{
				if(GetInputDown(0, "delete") || GetInputDown(0, "backspace") || GetInputDown(0, "left") || GetInputDown(0, "right")){
					long_press_timer += time_step;
				}else{
					long_press_timer = 0.0f;
				}
			}
			
			array<KeyboardPress> inputs = GetRawKeyboardInputs();
			if(inputs.size() > 0){
				uint16 possible_new_input = inputs[inputs.size()-1].s_id;
				if(possible_new_input != uint16(initial_sequence_id)){
					uint32 keycode = inputs[inputs.size()-1].keycode;
					initial_sequence_id = inputs[inputs.size()-1].s_id;
					//Print("new input = "+ keycode + "\n");
					bool get_upper_case = false;
					
					if(GetInputDown(ReadCharacter(player_id).controller_id, "shift")){
						get_upper_case =true;
					}
					
					array<int> ignore_keycodes = {27};
					if(ignore_keycodes.find(keycode) != -1 || keycode > 500){
						return;
					}
					//Enter/return pressed
					if(keycode == 13){
						current_index = 0;
						cursor_offset = 0;
						active = false;
						pressed_return = true;
						username = query;
						//Put the player state back so it can walk again.
						MovementObject@ player = ReadCharacter(player_id);
						player.velocity = vec3(0);
						player.Execute("SetState(_movement_state);");
						Deactivate();
						return;
					}
					//Backspace
					else if(keycode == 8){
						//Check if there are enough chars to delete the last one.
						if(query.length() - cursor_offset > 0){
							uint new_length = query.length() - 1;
							if(new_length >= 0 && new_length <= max_query_length){
								query.erase(query.length() - cursor_offset - 1, 1);
								active = true;
								SetCurrentSearchQuery();
								return;
							}
						}else{
							return;
						}
					}
					//Delete pressed
					else if(keycode == 127){
						if(cursor_offset > 0){
							query.erase(query.length() - cursor_offset, 1);
							cursor_offset--;
							active = true;
						}
						SetCurrentSearchQuery();
						return;
					}
					if(query.length() == 20){
						return;
					}
					if(get_upper_case){
						keycode = ToUpperCase(keycode);
					}
					string new_character('0');
					new_character[0] = keycode;
					query.insert(query.length() - cursor_offset, new_character);
					
					active = true;
					SetCurrentSearchQuery();
				}
			}
		}
	}
	void SetCurrentSearchQuery(){
		if(active && !pressed_return){
			parent.clear();
			@input_field = IMText("", client_connect_font);
			parent.append(input_field);
			IMText cursor("_", client_connect_font);
			cursor.addUpdateBehavior(pulse, "");
			if(cursor_offset > 0){
				string first_part = query.substr(0, query.length() - cursor_offset);
				input_field.setText(first_part);
				parent.append(cursor);
				string second_part = query.substr(query.length() - cursor_offset, query.length());
				IMText second_input_field(second_part, client_connect_font);
				parent.append(second_input_field);
			}else{
				input_field.setText(query);
				parent.append(cursor);
			}
		}
	}
	void ShowSearchResults(){
		
	}
	void GetSearchResults(string query){
		
	}
}
uint32 ToUpperCase(uint32 input){
	uint32 return_value = input;
	//Check if keycode is between a and z
	if(input >= 97 || input <= 122){
		return_value -= 32;
	}
	return return_value;
}